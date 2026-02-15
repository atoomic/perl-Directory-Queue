#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use No::Worries::File qw(file_write);
use Test::More tests => 33;

use Directory::Queue::Simple;

our($tmpdir, $dq, $elt, $tmp);

$tmpdir = tempdir(CLEANUP => 1);

#
# Test add_ref()
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q1");
my $data = "hello via reference";
$elt = $dq->add_ref(\$data);
ok($elt, "add_ref returns element name");
ok($dq->lock($elt), "lock after add_ref");
my $got = $dq->get($elt);
is($got, "hello via reference", "get after add_ref");
$dq->remove($elt);
is($dq->count(), 0, "count 0 after remove");

#
# Test add_path()
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q2");
my $file = "$tmpdir/external_file";
file_write($file, data => "path data");
ok(-f $file, "external file exists");
$elt = $dq->add_path($file);
ok($elt, "add_path returns element name");
ok(!-f $file, "external file moved into queue");
ok($dq->lock($elt), "lock after add_path");
$got = $dq->get($elt);
is($got, "path data", "get after add_path");
$dq->remove($elt);

#
# Test get_path()
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q3");
$elt = $dq->add("get_path test");
ok($dq->lock($elt), "lock for get_path");
my $path = $dq->get_path($elt);
ok(-f $path, "get_path returns existing file");
like($path, qr/\.lck$/, "get_path returns .lck path");
$got = do { open(my $fh, "<", $path); local $/; <$fh> };
is($got, "get_path test", "file content matches");
$dq->remove($elt);

#
# Test touch()
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q4");
$elt = $dq->add("touch test");
my $before = (stat("$tmpdir/q4/$elt"))[9];
sleep(1);
$dq->touch($elt);
my $after = (stat("$tmpdir/q4/$elt"))[9];
ok($after >= $before, "touch updates mtime");

#
# Test granularity option
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q5", granularity => 0);
$elt = $dq->add("granularity 0");
ok($elt, "add with granularity 0");
is($dq->count(), 1, "count with granularity 0");

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q6", granularity => 3600);
$elt = $dq->add("granularity 3600");
ok($elt, "add with granularity 3600");
is($dq->count(), 1, "count with granularity 3600");

# Invalid granularity
eval { Directory::Queue::Simple->new(path => "$tmpdir/q7", granularity => "abc") };
like($@, qr/invalid granularity/, "invalid granularity");

# Unexpected option
eval { Directory::Queue::Simple->new(path => "$tmpdir/q8", bogus => 1) };
like($@, qr/unexpected option/, "unexpected option");

#
# Test non-permissive lock/unlock
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q9");
$elt = $dq->add("lock test");

# Non-permissive lock on already-locked element
ok($dq->lock($elt), "first lock succeeds");
# Try to lock again (permissive = default)
ok(!$dq->lock($elt), "second lock fails (permissive)");

$dq->unlock($elt);
# unlock when already unlocked (non-permissive should die)
eval { $dq->unlock($elt, 0) };
like($@, qr/cannot unlink/, "non-permissive unlock on unlocked element dies");

# unlock permissive on unlocked element returns false
ok(!$dq->unlock($elt, 1), "permissive unlock on unlocked element returns false");

#
# Test lock on non-existent element (permissive)
#

ok(!$dq->lock("00000000/nonexistent12345", 1), "lock non-existent permissive returns false");

#
# Test remove on unlocked element
#

$elt = $dq->add("remove unlocked test");
eval { $dq->remove($elt) };
ok($@, "remove on unlocked element dies");

#
# Test purge with maxlock
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q10");
$elt = $dq->add("purge lock test");
ok($dq->lock($elt), "lock for purge test");

# Age the lock file
my $old_time = time() - 1000;
my $lock_path = "$tmpdir/q10/$elt.lck";
utime($old_time, $old_time, $lock_path)
    or die "cannot utime: $!";
utime($old_time, $old_time, "$tmpdir/q10/$elt")
    or die "cannot utime: $!";

$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxlock => 5);
}
is($tmp, 1, "purge removed old lock");
# Element still exists but is now unlocked
ok($dq->lock($elt), "can re-lock after purge");
$dq->remove($elt);

#
# Test purge with maxtemp=0 and maxlock=0 (disabled)
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q11");
$elt = $dq->add("purge disabled test");
$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ };
    $dq->purge(maxtemp => 0, maxlock => 0);
}
is($tmp, 0, "purge with maxtemp=0 maxlock=0 does nothing");
is($dq->count(), 1, "element still there after no-op purge");

#
# Test purge with invalid options
#

eval { $dq->purge(bogus => 1) };
like($@, qr/unexpected option/, "purge with unexpected option dies");

eval { $dq->purge(maxtemp => "abc") };
like($@, qr/invalid maxtemp/, "purge with invalid maxtemp dies");
