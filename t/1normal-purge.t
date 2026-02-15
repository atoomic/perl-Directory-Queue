#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use No::Worries::Dir qw(dir_read);
use Test::More tests => 17;

use Directory::Queue::Normal;

our($tmpdir, $dq, $elt, $tmp, $time);

$tmpdir = tempdir(CLEANUP => 1);

#
# Test purge: remove old temporary elements
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q1",
    schema => { body => "string" },
);

# Create a temporary directory manually (simulating an interrupted add)
my $temp_path = "$tmpdir/q1/temporary";
my $fake_temp = "$temp_path/00000000000001";
mkdir($fake_temp) or die "cannot mkdir: $!";
# Make it old
$time = time() - 1000;
utime($time, $time, $fake_temp) or die "cannot utime: $!";

$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ if $_[0] =~ /removing too old volatile/ };
    $dq->purge(maxtemp => 5);
}
is($tmp, 1, "purge removed old temporary element");
ok(!-d $fake_temp, "old temporary directory removed");

#
# Test purge: remove old temporary elements (recent ones should be kept)
#

$fake_temp = "$temp_path/00000000000002";
mkdir($fake_temp) or die "cannot mkdir: $!";
# Don't age it - it's fresh

$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ };
    $dq->purge(maxtemp => 5);
}
is($tmp, 0, "purge keeps recent temporary element");
ok(-d $fake_temp, "recent temporary directory preserved");
rmdir($fake_temp);

#
# Test purge: unlock stale locks
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q2",
    schema => { body => "string" },
);

$elt = $dq->add(body => "lock purge test 1");
my $elt2 = $dq->add(body => "lock purge test 2");

# Lock both
ok($dq->lock($elt), "lock element 1");
ok($dq->lock($elt2), "lock element 2");

# Age element 1's directory
my $elt_path = "$tmpdir/q2/$elt";
$time = time() - 1000;
utime($time, $time, $elt_path) or die "cannot utime: $!";

# Touch element 2 (keep it recent)
$dq->touch($elt2);

$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ if $_[0] =~ /removing too old locked/ };
    $dq->purge(maxlock => 5);
}
is($tmp, 1, "purge unlocked 1 stale lock");

# Element 1 should now be unlockable again
ok($dq->lock($elt), "can re-lock element 1 after purge");
$dq->remove($elt);

# Element 2 should still be locked
ok($dq->_is_locked($elt2), "element 2 still locked");
$dq->remove($elt2);

#
# Test purge: remove empty intermediate directories
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q3",
    schema => { body => "string" },
    maxelts => 1,
);

# Add 3 elements to create multiple intermediate dirs
my @elts;
for (1..3) {
    push @elts, $dq->add(body => "multi $_");
}

# Count intermediate dirs
my @dirs = grep { /^[0-9a-f]{8}$/ } dir_read("$tmpdir/q3");
ok(scalar(@dirs) >= 2, "multiple intermediate directories exist");

# Remove all elements
for my $e (@elts) {
    $dq->lock($e) and $dq->remove($e);
}
is($dq->count(), 0, "all elements removed");

# Purge should clean up empty intermediate dirs (keeps last one)
$dq->purge();
@dirs = grep { /^[0-9a-f]{8}$/ } dir_read("$tmpdir/q3");
is(scalar(@dirs), 1, "purge cleaned empty intermediate dirs (kept 1)");

#
# Test obsolete directory handling
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q4",
    schema => { body => "string" },
);

# Create a fake obsolete directory
my $obs_path = "$tmpdir/q4/obsolete";
my $fake_obs = "$obs_path/00000000000001";
mkdir($fake_obs) or die "cannot mkdir: $!";
$time = time() - 1000;
utime($time, $time, $fake_obs) or die "cannot utime: $!";

$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ if $_[0] =~ /removing too old volatile/ };
    $dq->purge(maxtemp => 5);
}
is($tmp, 1, "purge removed old obsolete element");
ok(!-d $fake_obs, "old obsolete directory removed");

#
# Test _is_locked with time parameter
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q5",
    schema => { body => "string" },
);
$elt = $dq->add(body => "timed lock test");
ok($dq->lock($elt), "lock for timed test");

# Recently locked element is not older than a past time
ok(!$dq->_is_locked($elt, time() - 1000), "not older than past time");

# Recently locked element IS older than a future time
ok($dq->_is_locked($elt, time() + 1000), "older than future time");
$dq->remove($elt);
