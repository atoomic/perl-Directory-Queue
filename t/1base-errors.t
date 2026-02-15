#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 17;

use Directory::Queue;
use Directory::Queue::Simple;

our($tmpdir);

$tmpdir = tempdir(CLEANUP => 1);

# _new() error paths

# missing path option
eval { Directory::Queue::Simple->new() };
like($@, qr/missing option: path/, "missing path option");

# path exists but is not a directory
my $file = "$tmpdir/not_a_dir";
open(my $fh, ">", $file) or die "cannot create $file: $!";
close($fh);
eval { Directory::Queue::Simple->new(path => $file) };
like($@, qr/not a directory/, "path is not a directory");

# invalid integer options
eval { Directory::Queue::Simple->new(path => "$tmpdir/q1", maxlock => "abc") };
like($@, qr/invalid maxlock/, "invalid maxlock");

eval { Directory::Queue::Simple->new(path => "$tmpdir/q2", maxtemp => "xyz") };
like($@, qr/invalid maxtemp/, "invalid maxtemp");

eval { Directory::Queue::Simple->new(path => "$tmpdir/q3", umask => "bad") };
like($@, qr/invalid umask/, "invalid umask");

eval { Directory::Queue::Simple->new(path => "$tmpdir/q4", rndhex => "bad") };
like($@, qr/invalid rndhex/, "invalid rndhex");

# rndhex too large (must be < 16)
eval { Directory::Queue::Simple->new(path => "$tmpdir/q5", rndhex => 16) };
like($@, qr/invalid rndhex/, "rndhex >= 16");

# rndhex at boundary (15 is valid)
my $dq = Directory::Queue::Simple->new(path => "$tmpdir/q6", rndhex => 15);
ok($dq, "rndhex 15 is valid");

# umask too large (must be < 512)
eval { Directory::Queue::Simple->new(path => "$tmpdir/q7", umask => 512) };
like($@, qr/invalid umask/, "umask >= 512");

# umask at boundary (511 is valid = 0777)
$dq = Directory::Queue::Simple->new(path => "$tmpdir/q8", umask => 511);
ok($dq, "umask 511 is valid");

# _require error path (bad module name)
eval { Directory::Queue->new(type => "NonExistentModule", path => "$tmpdir/q9") };
like($@, qr/failed to load/, "bad module type");

# Verify path() and id() on base class via Simple
$dq = Directory::Queue::Simple->new(path => "$tmpdir/qbase");
is($dq->path(), "$tmpdir/qbase", "path()");
ok(defined($dq->id()), "id() defined");

# copy() produces independent iterator state
$dq->add("test1");
$dq->add("test2");
my $copy = $dq->copy();
my $first_orig = $dq->first();
my $first_copy = $copy->first();
is($first_orig, $first_copy, "copy has same first element");
my $next_orig = $dq->next();
my $next_copy = $copy->next();
is($next_orig, $next_copy, "copy has same next element");

# Verify copy is truly independent
$copy = $dq->copy();
$dq->first(); # reset original iterator
$copy->first();
$dq->next(); # advance original
# copy should still be at first position after its own next
my $copy_next = $copy->next();
ok($copy_next, "copy iterator is independent from original");

# empty queue iteration
my $empty_dq = Directory::Queue::Simple->new(path => "$tmpdir/qempty");
is($empty_dq->first(), "", "first() on empty queue returns empty string");
