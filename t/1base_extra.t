#!perl

use strict;
use warnings;
use Directory::Queue qw();
use Directory::Queue::Simple qw();
use File::Temp qw(tempdir);
use Test::More tests => 22;

my ($tmpdir, $dq, $copy, $elt, @elts);

$tmpdir = tempdir(CLEANUP => 1);

# --- factory method default type ---

$dq = Directory::Queue->new(path => "$tmpdir/factory1");
isa_ok($dq, "Directory::Queue::Simple", "default type is Simple");
isa_ok($dq, "Directory::Queue", "inherits from Directory::Queue");

# --- factory method with explicit type ---

$dq = Directory::Queue->new(path => "$tmpdir/factory2", type => "Normal",
                             schema => { body => "string" });
isa_ok($dq, "Directory::Queue::Normal", "type=Normal works");

$dq = Directory::Queue->new(path => "$tmpdir/factory3", type => "Null");
isa_ok($dq, "Directory::Queue::Null", "type=Null works");

# --- factory with invalid type ---

eval { Directory::Queue->new(path => "$tmpdir/factory4", type => "NonExistent") };
like($@, qr/failed to load/, "invalid type dies");

# --- missing path option ---

eval { Directory::Queue::Simple->new() };
like($@, qr/missing option: path/, "missing path dies");

# --- path pointing to a file (not directory) ---

my $file_path = "$tmpdir/not_a_dir";
open(my $fh, ">", $file_path) or die "cannot create: $!";
close($fh);
eval { Directory::Queue::Simple->new(path => $file_path) };
like($@, qr/not a directory/, "file as path dies");

# --- invalid integer options ---

eval { Directory::Queue::Simple->new(path => "$tmpdir/inv1", maxlock => "abc") };
like($@, qr/invalid maxlock/, "non-numeric maxlock dies");

eval { Directory::Queue::Simple->new(path => "$tmpdir/inv2", maxtemp => "xyz") };
like($@, qr/invalid maxtemp/, "non-numeric maxtemp dies");

eval { Directory::Queue::Simple->new(path => "$tmpdir/inv3", rndhex => "bad") };
like($@, qr/invalid rndhex/, "non-numeric rndhex dies");

# --- rndhex out of range ---

eval { Directory::Queue::Simple->new(path => "$tmpdir/inv4", rndhex => 16) };
like($@, qr/invalid rndhex/, "rndhex=16 dies (must be < 16)");

# --- umask out of range ---

eval { Directory::Queue::Simple->new(path => "$tmpdir/inv5", umask => 512) };
like($@, qr/invalid umask/, "umask=512 dies (must be < 512)");

# --- valid rndhex and umask ---

$dq = Directory::Queue::Simple->new(path => "$tmpdir/val1", rndhex => 0);
ok($dq, "rndhex=0 is valid");

$dq = Directory::Queue::Simple->new(path => "$tmpdir/val2", rndhex => 15);
ok($dq, "rndhex=15 is valid");

$dq = Directory::Queue::Simple->new(path => "$tmpdir/val3", umask => 0);
ok($dq, "umask=0 is valid");

# --- copy() creates independent iterator ---

$dq = Directory::Queue::Simple->new(path => "$tmpdir/copy1");
for (1..5) {
    $dq->add("element $_");
}

$copy = $dq->copy();
isa_ok($copy, "Directory::Queue::Simple", "copy is same class");
is($copy->path(), $dq->path(), "copy has same path");
is($copy->id(), $dq->id(), "copy has same id");

# iterate original partially
my $first = $dq->first();
ok($first, "original first works");
my $second = $dq->next();
ok($second, "original next works");

# copy's iterator should be independent
my $copy_first = $copy->first();
ok($copy_first, "copy first works independently");
is($copy_first, $first, "copy starts from the same first element");
