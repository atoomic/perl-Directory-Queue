#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 17;

use Directory::Queue::Simple;

my $tmpdir = tempdir(CLEANUP => 1);

#
# Test purge() stale lock removal via _purge_dir()
#

my $dq = Directory::Queue::Simple->new(path => "$tmpdir/q1");
my $elt = $dq->add("purge stale lock test");
ok($dq->lock($elt), "lock element");

# Age both the element and lock files
my $old_time = time() - 700;
my $lock_path = "$tmpdir/q1/$elt.lck";
utime($old_time, $old_time, "$tmpdir/q1/$elt") or die "cannot utime: $!";
utime($old_time, $old_time, $lock_path) or die "cannot utime: $!";

# Purge with explicit maxlock should remove the stale lock
my $warned = 0;
{
    local $SIG{__WARN__} = sub { $warned++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxlock => 5);
}
is($warned, 1, "purge removed stale lock file");
ok(!-f $lock_path, "lock file is gone");
ok(-f "$tmpdir/q1/$elt", "element file still exists");

#
# Test purge() stale temp removal
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q2");
# Manually create a .tmp file inside an intermediate directory
my $dir = sprintf("%08x", time() - time() % 60);
mkdir("$tmpdir/q2/$dir") unless -d "$tmpdir/q2/$dir";
my $tmp_file = "$tmpdir/q2/$dir/00000000000000.tmp";
open(my $fh, ">", $tmp_file) or die "cannot create: $!";
print $fh "stale temp data";
close($fh);
# Age it
utime($old_time, $old_time, $tmp_file);

$warned = 0;
{
    local $SIG{__WARN__} = sub { $warned++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxtemp => 5);
}
is($warned, 1, "purge removed stale temp file");
ok(!-f $tmp_file, "temp file is gone");

#
# Test purge() removes empty intermediate directories
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q3", granularity => 0);
# Add to two different time-based directories
my $elt1 = $dq->add("dir cleanup 1");
sleep(1);
my $elt2 = $dq->add("dir cleanup 2");

# Verify we have elements
is($dq->count(), 2, "two elements before cleanup");

# Lock and remove both
ok($dq->lock($elt1), "lock first");
$dq->remove($elt1);
ok($dq->lock($elt2), "lock second");
$dq->remove($elt2);
is($dq->count(), 0, "zero elements after removal");

# Count intermediate directories before purge
opendir(my $dh, "$tmpdir/q3") or die "opendir: $!";
my @dirs_before = grep { /^[0-9a-f]{8}$/ } readdir($dh);
closedir($dh);

# Purge should clean up empty intermediate dirs (except the last)
$dq->purge();

opendir($dh, "$tmpdir/q3") or die "opendir: $!";
my @dirs_after = grep { /^[0-9a-f]{8}$/ } readdir($dh);
closedir($dh);

ok(@dirs_after <= @dirs_before, "purge cleaned intermediate directories");

#
# Test purge with maxlock=0 disabling lock cleanup while maxtemp still runs
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q4");
$elt = $dq->add("independence test");
ok($dq->lock($elt), "lock for independence test");

# Create a stale .tmp file
$dir = sprintf("%08x", time() - time() % 60);
mkdir("$tmpdir/q4/$dir") unless -d "$tmpdir/q4/$dir";
$tmp_file = "$tmpdir/q4/$dir/00000000000001.tmp";
open($fh, ">", $tmp_file) or die "cannot create: $!";
close($fh);
utime($old_time, $old_time, $tmp_file);

# Age the lock too
utime($old_time, $old_time, "$tmpdir/q4/$elt");
utime($old_time, $old_time, "$tmpdir/q4/$elt.lck");

$warned = 0;
{
    local $SIG{__WARN__} = sub { $warned++ };
    $dq->purge(maxtemp => 5, maxlock => 0);
}
is($warned, 1, "only temp file removed, lock preserved");
ok(!-f $tmp_file, "temp file removed");
ok(-f "$tmpdir/q4/$elt.lck", "lock file preserved when maxlock=0");

#
# Test purge with maxtemp=0 disabling temp cleanup while maxlock still runs
#

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q5");
$elt = $dq->add("reverse independence test");
ok($dq->lock($elt), "lock for reverse test");

# Age lock only
utime($old_time, $old_time, "$tmpdir/q5/$elt");
utime($old_time, $old_time, "$tmpdir/q5/$elt.lck");

$warned = 0;
{
    local $SIG{__WARN__} = sub { $warned++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxtemp => 0, maxlock => 5);
}
is($warned, 1, "lock cleaned when maxtemp=0 but maxlock active");
