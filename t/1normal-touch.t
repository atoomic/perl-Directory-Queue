#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 8;

use Directory::Queue::Normal;

my $tmpdir = tempdir(CLEANUP => 1);

#
# Test touch() actually updates mtime
#

my $dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q1",
    schema => { body => "string" },
);
my $elt = $dq->add(body => "touch mtime test");
ok($dq->lock($elt), "lock element");

my $elt_path = "$tmpdir/q1/$elt";
my $before = (stat($elt_path))[9];
sleep(1);
$dq->touch($elt);
my $after = (stat($elt_path))[9];
ok($after > $before, "touch updates element mtime");

$dq->remove($elt);

#
# Test touch() prevents purge from unlocking a recently-touched element
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q2",
    schema => { body => "string" },
);
$elt = $dq->add(body => "touch vs purge");
ok($dq->lock($elt), "lock element");

# Age the element directory to look stale
my $old_time = time() - 1000;
$elt_path = "$tmpdir/q2/$elt";
utime($old_time, $old_time, $elt_path);

# Touch it to make it recent again
$dq->touch($elt);

# Purge should NOT unlock it (it was just touched)
my $warned = 0;
{
    local $SIG{__WARN__} = sub { $warned++ };
    $dq->purge(maxlock => 5);
}
is($warned, 0, "purge skips recently-touched element");
ok(-d "$elt_path/locked", "element remains locked after purge");

$dq->remove($elt);

#
# Test copy() creates independent iterator for Normal queue
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q3",
    schema => { body => "string" },
);

# Add 3 elements
$dq->add(body => "one");
$dq->add(body => "two");
$dq->add(body => "three");

# Start iterating on original
my $first = $dq->first();
ok($first, "original iterator returns first element");

# Copy and iterate independently
my $copy = $dq->copy();
my $copy_first = $copy->first();
ok($copy_first, "copy iterator returns first element");

# Advance original to collect all elements
my @orig_elts;
push @orig_elts, $first;
while (my $next = $dq->next()) {
    push @orig_elts, $next;
}
is(scalar(@orig_elts), 3, "original iterator sees all 3 elements independently");
