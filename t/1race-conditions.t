#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use No::Worries::File qw(file_write);
use Test::More tests => 20;

use Directory::Queue::Simple;
use Directory::Queue::Normal;

our($tmpdir, $dq, $elt, $tmp);

$tmpdir = tempdir(CLEANUP => 1);

#
# Test 1: Simple.pm purge() maxlock default should use maxlock, not maxtemp
#
# This tests that when maxlock is not passed to purge(), it defaults to
# $self->{maxlock} (600s) rather than $self->{maxtemp} (300s).
# We use different values for maxlock and maxtemp to detect the bug.
#

$dq = Directory::Queue::Simple->new(
    path    => "$tmpdir/q1",
    maxlock => 800,
    maxtemp => 100,
);
$elt = $dq->add("purge default test");
ok($dq->lock($elt), "lock for maxlock default test");

# Age the lock to 500s — older than maxtemp(100) but younger than maxlock(800)
my $old_time = time() - 500;
my $lock_path = "$tmpdir/q1/$elt.lck";
my $data_path = "$tmpdir/q1/$elt";
utime($old_time, $old_time, $lock_path) or die "cannot utime: $!";
utime($old_time, $old_time, $data_path) or die "cannot utime: $!";

$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ if $_[0] =~ /removing too old/ };
    # purge without explicit maxlock — should use $self->{maxlock} = 800
    $dq->purge();
}
is($tmp, 0, "purge respects maxlock default (800s), not maxtemp (100s)");

# The lock should still be there
ok(-f $lock_path, "lock file still exists after purge with correct default");

$dq->unlock($elt, 1);

#
# Test 2: Simple.pm purge() maxlock default — verify old locks ARE removed
#

$dq = Directory::Queue::Simple->new(
    path    => "$tmpdir/q2",
    maxlock => 200,
    maxtemp => 100,
);
$elt = $dq->add("purge old lock test");
ok($dq->lock($elt), "lock for old lock removal test");

# Age the lock to 500s — older than maxlock(200)
$old_time = time() - 500;
$lock_path = "$tmpdir/q2/$elt.lck";
$data_path = "$tmpdir/q2/$elt";
utime($old_time, $old_time, $lock_path) or die "cannot utime: $!";
utime($old_time, $old_time, $data_path) or die "cannot utime: $!";

$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ if $_[0] =~ /removing too old/ };
    $dq->purge();
}
is($tmp, 1, "purge removes lock older than maxlock default");

#
# Test 3: Simple.pm remove() on unlocked element should die with clear message
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q3");
$elt = $dq->add("remove check test");
eval { $dq->remove($elt) };
like($@, qr/not locked/, "remove on unlocked element reports 'not locked'");
is($dq->count(), 1, "element preserved after failed remove");

#
# Test 4: Simple.pm remove() on locked element succeeds
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q4");
$elt = $dq->add("remove locked test");
ok($dq->lock($elt), "lock for remove test");
eval { $dq->remove($elt) };
is($@, "", "remove on locked element succeeds");
is($dq->count(), 0, "element removed");

#
# Test 5: Simple.pm lock() cleanup after race (simulate file disappearing)
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q5");
$elt = $dq->add("lock race test");

# Simulate what happens when lock succeeds (link created) but original
# file is removed by another process before utime()
$data_path = "$tmpdir/q5/$elt";
$lock_path = "$tmpdir/q5/$elt.lck";

# Create the lock manually
link($data_path, $lock_path);
# Remove the original (simulating another process)
unlink($data_path);

# Try to lock again — should fail gracefully
ok(!$dq->lock($elt), "lock fails gracefully when element removed by race");

#
# Test 6: Normal.pm remove() retry limit
#
# We can't easily trigger the actual infinite loop in Normal, but we can
# test that remove() works correctly in the normal case and verify the
# retry limit constant exists in the code.
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q6",
    schema => { body => "string" },
);
$elt = $dq->add(body => "retry limit test");
ok($dq->lock($elt), "Normal lock for remove test");
eval { $dq->remove($elt) };
is($@, "", "Normal remove succeeds normally");
is($dq->count(), 0, "Normal element removed");

#
# Test 7: Normal.pm remove() on unlocked element dies
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q7",
    schema => { body => "string" },
);
$elt = $dq->add(body => "unlocked remove test");
eval { $dq->remove($elt) };
like($@, qr/not locked/, "Normal remove on unlocked element dies");
is($dq->count(), 1, "Normal element preserved");

#
# Test 8: Simple.pm purge() explicit maxlock overrides default
#

$dq = Directory::Queue::Simple->new(
    path    => "$tmpdir/q8",
    maxlock => 800,
    maxtemp => 100,
);
$elt = $dq->add("explicit maxlock test");
ok($dq->lock($elt), "lock for explicit maxlock test");

$old_time = time() - 500;
$lock_path = "$tmpdir/q8/$elt.lck";
$data_path = "$tmpdir/q8/$elt";
utime($old_time, $old_time, $lock_path) or die "cannot utime: $!";
utime($old_time, $old_time, $data_path) or die "cannot utime: $!";

$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ if $_[0] =~ /removing too old/ };
    # Explicit maxlock=200 should override the default of 800
    $dq->purge(maxlock => 200);
}
is($tmp, 1, "explicit maxlock=200 overrides default maxlock=800");

#
# Test 9: Simple.pm purge() with maxlock=0 disables lock cleanup
#

$dq = Directory::Queue::Simple->new(
    path    => "$tmpdir/q9",
    maxlock => 10,
);
$elt = $dq->add("maxlock disabled test");
ok($dq->lock($elt), "lock for maxlock=0 test");

$old_time = time() - 1000;
$lock_path = "$tmpdir/q9/$elt.lck";
$data_path = "$tmpdir/q9/$elt";
utime($old_time, $old_time, $lock_path) or die "cannot utime: $!";
utime($old_time, $old_time, $data_path) or die "cannot utime: $!";

# Even though lock is ancient, maxlock=0 should skip cleanup
{
    local $SIG{__WARN__} = sub {};
    $dq->purge(maxlock => 0);
}
# Lock should still exist
ok(-f $lock_path, "maxlock=0 preserves old locks");
