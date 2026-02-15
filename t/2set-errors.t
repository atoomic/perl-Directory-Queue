#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 14;

use Directory::Queue::Set;
use Directory::Queue::Simple;
use Directory::Queue::Normal;

our($tmpdir);

$tmpdir = tempdir(CLEANUP => 1);

#
# Error: add non-Directory::Queue object
#

my $dqs = Directory::Queue::Set->new();
eval { $dqs->add("not an object") };
like($@, qr/not a Directory::Queue object/, "add string to set dies");

eval { $dqs->add({ fake => 1 }) };
ok($@, "add hashref to set dies");

#
# Error: remove non-Directory::Queue object
#

eval { $dqs->remove("not an object") };
like($@, qr/not a Directory::Queue object/, "remove string from set dies");

#
# Error: duplicate queue in set
#

my $dq1 = Directory::Queue::Simple->new(path => "$tmpdir/s1");
$dqs = Directory::Queue::Set->new($dq1);
eval { $dqs->add($dq1) };
like($@, qr/duplicate queue in set/, "duplicate queue in set dies");

#
# Error: remove queue not in set
#

my $dq2 = Directory::Queue::Simple->new(path => "$tmpdir/s2");
eval { $dqs->remove($dq2) };
like($@, qr/missing queue in set/, "remove non-member queue dies");

#
# Empty set operations
#

$dqs = Directory::Queue::Set->new();
is($dqs->count(), 0, "empty set count is 0");
my @result = $dqs->first();
is(scalar(@result), 0, "empty set first returns empty list");

#
# Set with mixed queue types
#

my $dqn = Directory::Queue::Normal->new(
    path   => "$tmpdir/n1",
    schema => { body => "string" },
);
my $dqs2 = Directory::Queue::Simple->new(path => "$tmpdir/s3");

$dqn->add(body => "normal element");
$dqs2->add("simple element");

$dqs = Directory::Queue::Set->new($dqn, $dqs2);
is($dqs->count(), 2, "mixed set count");

my $count = 0;
my ($dq, $elt) = $dqs->first();
while ($dq) {
    $count++;
    ($dq, $elt) = $dqs->next();
}
is($count, 2, "mixed set iteration count");

#
# Add and remove queues dynamically
#

$dqs = Directory::Queue::Set->new($dqn);
is($dqs->count(), 1, "set with one queue");
$dqs->add($dqs2);
is($dqs->count(), 2, "set after adding second queue");
$dqs->remove($dqn);
is($dqs->count(), 1, "set after removing first queue");
$dqs->remove($dqs2);
is($dqs->count(), 0, "set after removing all queues");

#
# first() and next() after removing all queues
#

@result = $dqs->first();
is(scalar(@result), 0, "first on emptied set returns empty list");
