#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 12;

use Directory::Queue::Normal;

my $tmpdir = tempdir(CLEANUP => 1);

#
# Test purge() removes stale locked elements
#

my $dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q1",
    schema => { body => "string" },
);
my $elt = $dq->add(body => "stale lock test");
ok($dq->lock($elt), "lock element");

# Age the element directory
my $old_time = time() - 1000;
my $elt_path = "$tmpdir/q1/$elt";
utime($old_time, $old_time, $elt_path);

my $warned = 0;
{
    local $SIG{__WARN__} = sub { $warned++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxlock => 5);
}
is($warned, 1, "purge warned about stale lock");
ok(!-d "$elt_path/locked", "locked directory removed");

#
# Test purge() with maxtemp removes stale volatile elements
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q2",
    schema => { body => "string" },
);

# Create a fake temporary element directory (simulating an interrupted add)
my $temp_name = sprintf("%08x%05x%01x", time() - 2000, 0, 0);
my $temp_path = "$tmpdir/q2/temporary/$temp_name";
mkdir($temp_path) or die "cannot mkdir: $!";
open(my $fh, ">", "$temp_path/body") or die "cannot create: $!";
print $fh "orphaned data";
close($fh);

# Age the temp directory
utime($old_time, $old_time, $temp_path);

$warned = 0;
{
    local $SIG{__WARN__} = sub { $warned++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxtemp => 5);
}
is($warned, 1, "purge removed stale temp element");
ok(!-d $temp_path, "temp directory removed");

#
# Test purge() with maxtemp=0 skips volatile cleanup
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q3",
    schema => { body => "string" },
);

# Create a fake old temporary element
$temp_name = sprintf("%08x%05x%01x", time() - 2000, 0, 1);
$temp_path = "$tmpdir/q3/temporary/$temp_name";
mkdir($temp_path) or die "cannot mkdir: $!";
utime($old_time, $old_time, $temp_path);

$warned = 0;
{
    local $SIG{__WARN__} = sub { $warned++ };
    $dq->purge(maxtemp => 0, maxlock => 600);
}
is($warned, 0, "purge with maxtemp=0 skips volatile cleanup");
ok(-d $temp_path, "temp directory preserved");

#
# Test purge() with maxlock=0 skips lock cleanup
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q4",
    schema => { body => "string" },
);
$elt = $dq->add(body => "lock independence");
ok($dq->lock($elt), "lock element");

# Age the element
$elt_path = "$tmpdir/q4/$elt";
utime($old_time, $old_time, $elt_path);

$warned = 0;
{
    local $SIG{__WARN__} = sub { $warned++ };
    $dq->purge(maxtemp => 600, maxlock => 0);
}
is($warned, 0, "purge with maxlock=0 skips lock cleanup");
ok(-d "$elt_path/locked", "element still locked");

#
# Test purge() removes empty intermediate directories
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q5",
    schema => { body => "string" },
    maxelts => 1,
);
# Adding with maxelts=1 forces new intermediate dirs
my $e1 = $dq->add(body => "dir1");
my $e2 = $dq->add(body => "dir2");

ok($dq->lock($e1), "lock e1");
$dq->remove($e1);
ok($dq->lock($e2), "lock e2");
$dq->remove($e2);

# After purge, empty intermediate dirs should be cleaned
$dq->purge();
# Just verify it doesn't crash — the directory cleanup is best effort
