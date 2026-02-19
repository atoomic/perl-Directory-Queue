#!perl

use strict;
use warnings;
use Directory::Queue::Simple qw();
use File::Temp qw(tempdir);
use No::Worries::Dir qw(dir_read);
use Test::More tests => 30;

my ($tmpdir, $dq, $elt, $data, $ref, $path, @list);

$tmpdir = tempdir(CLEANUP => 1);

# --- add_ref ---

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q1");
my $bigdata = "hello world via reference";
$elt = $dq->add_ref(\$bigdata);
ok($elt, "add_ref returns element name");
like($elt, qr{^[0-9a-f]{8}/[0-9a-f]{14}$}, "add_ref element name format");

# lock, get, verify data
ok($dq->lock($elt), "lock after add_ref");
$data = $dq->get($elt);
is($data, "hello world via reference", "get after add_ref returns correct data");

# get_ref after add_ref
$ref = $dq->get_ref($elt);
is(ref($ref), "SCALAR", "get_ref returns scalar ref");
is($$ref, "hello world via reference", "get_ref content matches");

# get_path returns the locked file path
$path = $dq->get_path($elt);
like($path, qr/\.lck$/, "get_path returns path with .lck suffix");
ok(-f $path, "get_path file exists");

# read the file directly to verify
open(my $fh, "<", $path) or die "cannot open $path: $!";
my $file_content = do { local $/; <$fh> };
close($fh);
is($file_content, "hello world via reference", "get_path file contains correct data");

$dq->remove($elt);
is($dq->count(), 0, "remove after add_ref works");

# --- add_path ---

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q2");

# create a temporary file to add via path
my $src_file = "$tmpdir/source_file.txt";
open($fh, ">", $src_file) or die "cannot create $src_file: $!";
print $fh "data from external file";
close($fh);
ok(-f $src_file, "source file exists before add_path");

$elt = $dq->add_path($src_file);
ok($elt, "add_path returns element name");
like($elt, qr{^[0-9a-f]{8}/[0-9a-f]{14}$}, "add_path element name format");
ok(!-f $src_file, "source file removed after add_path (moved to queue)");

ok($dq->lock($elt), "lock after add_path");
$data = $dq->get($elt);
is($data, "data from external file", "get after add_path returns correct data");
$dq->remove($elt);

# --- granularity ---

# granularity=0 disables the modulo — full timestamp used as dir name
$dq = Directory::Queue::Simple->new(path => "$tmpdir/q3", granularity => 0);
$elt = $dq->add("test with granularity=0");
ok($elt, "add with granularity=0 succeeds");
@list = dir_read("$tmpdir/q3");
is(scalar(@list), 1, "one intermediate dir with granularity=0");
like($list[0], qr/^[0-9a-f]{8}$/, "intermediate dir is 8-hex with granularity=0");

# granularity=1 creates directories based on exact seconds
$dq = Directory::Queue::Simple->new(path => "$tmpdir/q4", granularity => 1);
$elt = $dq->add("test with granularity=1");
ok($elt, "add with granularity=1 succeeds");
is($dq->count(), 1, "count=1 with granularity=1");

# --- invalid granularity ---
eval { Directory::Queue::Simple->new(path => "$tmpdir/q5", granularity => "abc") };
like($@, qr/invalid granularity/, "invalid granularity dies");

# --- unexpected option ---
eval { Directory::Queue::Simple->new(path => "$tmpdir/q6", bogus => 42) };
like($@, qr/unexpected option/, "unexpected option dies");

# --- purge with maxlock ---

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q7");
$elt = $dq->add("lock test");
ok($dq->lock($elt), "lock for purge test");

# age the lock file
my $old_time = time() - 1000;
my $lock_path = "$tmpdir/q7/$elt.lck";
utime($old_time, $old_time, $lock_path) or die "cannot utime: $!";
# also age the element file itself
my $elem_path = "$tmpdir/q7/$elt";
utime($old_time, $old_time, $elem_path) or die "cannot utime: $!";

my $warn_count = 0;
{
    local $SIG{__WARN__} = sub { $warn_count++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxlock => 5);
}
is($warn_count, 1, "purge with maxlock removes old locks");

# --- non-permissive lock ---

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q8");
$elt = $dq->add("permissive test");
ok($dq->lock($elt), "first lock succeeds");
# try locking again, permissive mode (default) returns false
is($dq->lock($elt), 0, "second lock (permissive) returns 0");

# unlock with permissive=1 on already-unlocked element
$dq->unlock($elt);
is($dq->unlock($elt, 1), 0, "unlock permissive on unlocked returns 0");

# --- empty queue iteration ---

$dq = Directory::Queue::Simple->new(path => "$tmpdir/q9");
is($dq->first(), "", "first on empty queue returns empty string");
is($dq->next(), "", "next on empty queue returns empty string");
