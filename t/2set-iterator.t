#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 9;

use Directory::Queue::Simple;
use Directory::Queue::Normal;
use Directory::Queue::Set;

my $tmpdir = tempdir(CLEANUP => 1);

#
# Test next() before first() returns empty list
#

my $sq = Directory::Queue::Simple->new(path => "$tmpdir/sq1");
$sq->add("element 1");
$sq->add("element 2");

my $set = Directory::Queue::Set->new($sq);

# Call next() without first() — should return empty list, not crash
my @result = $set->next();
is(scalar(@result), 0, "next() before first() returns empty list");

# Now iterate normally
my ($dq, $elt) = $set->first();
ok($dq, "first() returns a queue");
ok($elt, "first() returns an element");

my $count = 1;
while (($dq, $elt) = $set->next()) {
    last unless $dq;
    $count++;
}
is($count, 2, "normal iteration after first() works");

#
# Test next() after iterator is exhausted returns empty list
#

($dq, $elt) = $set->next();
ok(!$dq, "next() after exhaustion returns empty");

#
# Test Set with Normal queues — copy() independence
#

my $nq = Directory::Queue::Normal->new(
    path   => "$tmpdir/nq1",
    schema => { body => "string" },
);
$nq->add(body => "normal 1");
$nq->add(body => "normal 2");

$set = Directory::Queue::Set->new($nq);
($dq, $elt) = $set->first();
ok($dq, "set with Normal queue returns first element");

$count = 1;
while (($dq, $elt) = $set->next()) {
    last unless $dq;
    $count++;
}
is($count, 2, "set iterates all Normal elements");

#
# Test Set count after removing all queues
#

$set = Directory::Queue::Set->new($sq);
is($set->count(), 2, "count before removal");
$set->remove($sq);
is($set->count(), 0, "count is 0 after removing all queues");
