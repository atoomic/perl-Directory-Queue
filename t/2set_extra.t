#!perl

use strict;
use warnings;
use Directory::Queue::Simple qw();
use Directory::Queue::Normal qw();
use Directory::Queue::Set qw();
use File::Temp qw(tempdir);
use Test::More tests => 16;

my ($tmpdir, $dq1, $dq2, $dqset, @result);

$tmpdir = tempdir(CLEANUP => 1);

# --- empty set ---

$dqset = Directory::Queue::Set->new();
is($dqset->count(), 0, "empty set count is 0");
@result = $dqset->first();
is(scalar(@result), 0, "first on empty set returns empty list");
@result = $dqset->next();
is(scalar(@result), 0, "next on empty set returns empty list");

# --- add non-DQ object ---

eval { $dqset->add("not a queue") };
like($@, qr/not a Directory::Queue object/, "add string dies");

eval { $dqset->add({}) };
ok($@, "add unblessed hash dies");

eval { $dqset->add(bless({}, "SomeOtherClass")) };
like($@, qr/not a Directory::Queue object/, "add wrong class dies");

# --- remove non-DQ object ---

eval { $dqset->remove("not a queue") };
like($@, qr/not a Directory::Queue object/, "remove string dies");

# --- duplicate queue ---

$dq1 = Directory::Queue::Simple->new(path => "$tmpdir/q1");
$dqset = Directory::Queue::Set->new($dq1);
eval { $dqset->add($dq1) };
like($@, qr/duplicate queue/, "duplicate queue in set dies");

# --- remove missing queue ---

$dq2 = Directory::Queue::Simple->new(path => "$tmpdir/q2");
eval { $dqset->remove($dq2) };
like($@, qr/missing queue/, "remove non-member queue dies");

# --- mixed queue types ---

$dq1 = Directory::Queue::Simple->new(path => "$tmpdir/mix1");
$dq2 = Directory::Queue::Normal->new(
    path   => "$tmpdir/mix2",
    schema => { body => "string" },
);

$dq1->add("simple data");
$dq2->add({ body => "normal data" });

$dqset = Directory::Queue::Set->new($dq1, $dq2);
is($dqset->count(), 2, "mixed set count is 2");

# iterate through all elements
my $count = 0;
my ($dq, $elt) = $dqset->first();
while ($dq) {
    $count++;
    ($dq, $elt) = $dqset->next();
}
is($count, 2, "iterate mixed set yields 2 elements");

# --- add and remove dynamically ---

$dqset = Directory::Queue::Set->new();
$dq1 = Directory::Queue::Simple->new(path => "$tmpdir/dyn1");
$dq1->add("item1");
$dq1->add("item2");

$dqset->add($dq1);
is($dqset->count(), 2, "count after adding queue with 2 elements");

$dqset->remove($dq1);
is($dqset->count(), 0, "count after removing queue is 0");

# --- copy behavior (queues in set are copies) ---

$dq1 = Directory::Queue::Simple->new(path => "$tmpdir/copy1");
$dq1->add("before");
$dqset = Directory::Queue::Set->new($dq1);
# add another element to original queue after creating set
$dq1->add("after");
# set should still see the new elements since it uses the same path
is($dqset->count(), 2, "set sees elements added to original queue (same path)");

# --- iteration ordering ---

$dq1 = Directory::Queue::Simple->new(path => "$tmpdir/ord1");
$dq2 = Directory::Queue::Simple->new(path => "$tmpdir/ord2");

# add elements with small delays to ensure ordering
my $e1 = $dq1->add("first");
select(undef, undef, undef, 0.01); # tiny delay
my $e2 = $dq2->add("second");

$dqset = Directory::Queue::Set->new($dq1, $dq2);
my ($first_dq, $first_elt) = $dqset->first();
ok(defined($first_dq), "first returns a queue");
ok(defined($first_elt), "first returns an element");
