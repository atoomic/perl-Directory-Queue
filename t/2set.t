#!perl

use strict;
use warnings;
use Directory::Queue;
use Directory::Queue::Normal;
use Directory::Queue::Set;
use Directory::Queue::Simple;
use Test::More tests => 11;
use File::Temp qw(tempdir);

our($tmpdir, $dq1, $dq2, $elt1, $elt2, $dqs, $dq, $elt, @list);

$tmpdir = tempdir(CLEANUP => 1);
#diag("Using temporary directory $tmpdir");

$dq1 = Directory::Queue::Normal->new(path => "$tmpdir/1", "schema" => { string => "string" });
$dq2 = Directory::Queue::Simple->new(path => "$tmpdir/2");
isnt($dq1->path(), $dq2->path(), "different queues have different paths");
isnt($dq1->id(), $dq2->id(), "different queues have different ids");
is($dq1->id(), $dq1->copy()->id(), "copy preserves queue id");

$elt1 = $dq1->add(string => "test dq1.1");
$elt2 = $dq2->add("test dq2.1");
$dq1->add(string => "test dq1.2");
$dq2->add("test dq2.2");

$dqs = Directory::Queue::Set->new();
is($dqs->count(), 0, "empty set has count 0");

$dqs = Directory::Queue::Set->new($dq1, $dq2);
$dqs->remove($dq1);
is($dqs->count(), 2, "count after removing one queue");
$dqs->add($dq1);
is($dqs->count(), 4, "count after re-adding queue");

for (($dq, $elt) = $dqs->first(); $dq; ($dq, $elt) = $dqs->next()) {
    push(@list, $elt);
}
is(scalar(@list), 4, "set iterates all 4 elements from both queues");

@list = grep($_ eq $elt1 || $_ eq $elt2, @list);
if (substr($elt1, -14) lt substr($elt2, -14)) {
    like(" @list ", qr/ $elt1 $elt2 /, "elements sorted by time across queues");
} else {
    like(" @list ", qr/ $elt2 $elt1 /, "elements sorted by time across queues");
}

($dq, $elt) = $dqs->first();
$dq->lock($elt) and $dq->remove($elt);

($dq, $elt) = $dqs->next();
$dq->lock($elt) and $dq->remove($elt);

($dq, $elt) = $dqs->next();
$dq->lock($elt) and $dq->remove($elt);

($dq, $elt) = $dqs->next();
# last one

if ($dq1->id() eq $dq->id()) {
    is($dq1->count(), 1, "last element belongs to Normal queue");
    is($dq2->count(), 0, "Simple queue is empty");
} elsif ($dq2->id() eq $dq->id()) {
    is($dq1->count(), 0, "Normal queue is empty");
    is($dq2->count(), 1, "last element belongs to Simple queue");
} else {
    # error
    is($dq1->count(), "?", "unexpected queue identity (Normal)");
    is($dq2->count(), "?", "unexpected queue identity (Simple)");
}

($dq, $elt) = $dqs->next();
ok(!defined($dq), "next() returns undef after exhaustion");
