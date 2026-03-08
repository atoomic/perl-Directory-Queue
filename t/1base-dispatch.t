#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 8;

use Directory::Queue;

my $tmpdir = tempdir(CLEANUP => 1);

#
# Test base class new() type dispatch
#

# Default type is Simple
my $dq = Directory::Queue->new(path => "$tmpdir/q1");
isa_ok($dq, "Directory::Queue::Simple", "default type is Simple");
isa_ok($dq, "Directory::Queue", "inherits from Directory::Queue");

# Explicit Simple type
$dq = Directory::Queue->new(type => "Simple", path => "$tmpdir/q2");
isa_ok($dq, "Directory::Queue::Simple", "explicit Simple type");

# Explicit Normal type
$dq = Directory::Queue->new(
    type   => "Normal",
    path   => "$tmpdir/q3",
    schema => { body => "string" },
);
isa_ok($dq, "Directory::Queue::Normal", "explicit Normal type");

# Explicit Null type
$dq = Directory::Queue->new(type => "Null", path => "$tmpdir/q4");
isa_ok($dq, "Directory::Queue::Null", "explicit Null type");

# Invalid type
eval { Directory::Queue->new(type => "NonExistent", path => "$tmpdir/q5") };
like($@, qr/failed to load/, "invalid type dies");

#
# Test _path2id produces unique ids
#

my $dq1 = Directory::Queue->new(path => "$tmpdir/q6a");
my $dq2 = Directory::Queue->new(path => "$tmpdir/q6b");
isnt($dq1->id(), $dq2->id(), "different paths produce different ids");

# Same path produces same id
my $dq3 = Directory::Queue->new(path => "$tmpdir/q6a");
is($dq1->id(), $dq3->id(), "same path produces same id");
