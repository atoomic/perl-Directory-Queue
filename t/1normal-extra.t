#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use No::Worries::Dir qw(dir_read);
use Test::More tests => 43;

use Directory::Queue::Normal;

our($tmpdir, $dq, $elt, $tmp);

$tmpdir = tempdir(CLEANUP => 1);

#
# Schema validation errors
#

# Invalid schema type
eval {
    Directory::Queue::Normal->new(
        path   => "$tmpdir/q1",
        schema => { body => "invalid_type" },
    );
};
like($@, qr/invalid schema type/, "invalid schema type");

# Schema with 'locked' name (conflicts with LOCKED_DIRECTORY)
eval {
    Directory::Queue::Normal->new(
        path   => "$tmpdir/q2",
        schema => { locked => "string" },
    );
};
like($@, qr/invalid schema name/, "schema name 'locked' rejected");

# Invalid schema name (special characters)
eval {
    Directory::Queue::Normal->new(
        path   => "$tmpdir/q3",
        schema => { "bad-name" => "string" },
    );
};
like($@, qr/invalid schema name/, "invalid schema name");

# Schema with no mandatory data
eval {
    Directory::Queue::Normal->new(
        path   => "$tmpdir/q4",
        schema => { body => "string?" },
    );
};
like($@, qr/no mandatory data/, "schema with no mandatory data");

# Table with reference (invalid combination)
eval {
    Directory::Queue::Normal->new(
        path   => "$tmpdir/q5",
        schema => { data => "table*" },
    );
};
like($@, qr/invalid schema type/, "table with reference modifier");

# Invalid maxelts
eval {
    Directory::Queue::Normal->new(
        path    => "$tmpdir/q6",
        schema  => { body => "string" },
        maxelts => 0,
    );
};
like($@, qr/invalid maxelts/, "maxelts 0 is invalid");

eval {
    Directory::Queue::Normal->new(
        path    => "$tmpdir/q7",
        schema  => { body => "string" },
        maxelts => "abc",
    );
};
like($@, qr/invalid maxelts/, "maxelts non-numeric is invalid");

# Unexpected option
eval {
    Directory::Queue::Normal->new(
        path   => "$tmpdir/q8",
        schema => { body => "string" },
        bogus  => 1,
    );
};
like($@, qr/unexpected option/, "unexpected option");

# Schema not a hash
eval {
    Directory::Queue::Normal->new(
        path   => "$tmpdir/q9",
        schema => "not_a_hash",
    );
};
like($@, qr/invalid schema/, "schema not a hash");

#
# get() without schema
#

$dq = Directory::Queue::Normal->new(path => "$tmpdir/q10");
eval { $dq->get("00000000/00000000000000") };
like($@, qr/unknown schema/, "get without schema");

#
# add() without schema
#

eval { $dq->add(body => "test") };
like($@, qr/unknown schema/, "add without schema");

#
# add() with missing mandatory data
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q11",
    schema => { body => "string", header => "table" },
);
eval { $dq->add(body => "test") };
like($@, qr/missing mandatory data/, "add with missing mandatory data");

#
# add() with unexpected data
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q12",
    schema => { body => "string" },
);
eval { $dq->add(body => "test", bogus => "data") };
like($@, qr/unexpected data/, "add with unexpected data field");

#
# Non-permissive lock on missing element
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q13",
    schema => { body => "string" },
);
# Create intermediate dir so lock() actually tries mkdir for the locked/ subdir
mkdir("$tmpdir/q13/00000000");
# Use a valid element name (8hex/14hex) but non-existent element directory
eval { $dq->lock("00000000/00000000000001", 0) };
like($@, qr/cannot mkdir/, "non-permissive lock on missing element dies");

# Permissive lock on missing element
ok(!$dq->lock("00000000/00000000000001", 1), "permissive lock on missing returns false");

#
# Non-permissive unlock on already-unlocked element
#

$elt = $dq->add(body => "unlock test");
ok($dq->lock($elt), "lock for unlock test");
ok($dq->unlock($elt), "first unlock succeeds");
eval { $dq->unlock($elt, 0) };
like($@, qr/cannot rmdir/, "non-permissive unlock on unlocked dies");

# Permissive unlock on unlocked
ok(!$dq->unlock($elt, 1), "permissive unlock on unlocked returns false");

#
# remove() on unlocked element
#

$elt = $dq->add(body => "remove unlocked");
eval { $dq->remove($elt) };
like($@, qr/not locked/, "remove on unlocked element dies");

#
# get() on unlocked element
#

eval { $dq->get($elt) };
like($@, qr/not locked/, "get on unlocked element dies");

#
# Invalid element name
#

eval { $dq->lock("bad/element/name") };
like($@, qr/invalid element/, "invalid element name in lock");

eval { $dq->unlock("bad/element/name") };
like($@, qr/invalid element/, "invalid element name in unlock");

eval { $dq->remove("bad/element/name") };
like($@, qr/invalid element/, "invalid element name in remove");

#
# nlink option
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q14",
    schema => { body => "string" },
    nlink  => 1,
);
$elt = $dq->add(body => "nlink test 1");
is($dq->count(), 1, "count with nlink=1");
$dq->add(body => "nlink test 2");
is($dq->count(), 2, "count with nlink=1 (2 elements)");

#
# Optional data field
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q15",
    schema => { body => "string", notes => "string?" },
);

# add without optional field
$elt = $dq->add(body => "required only");
ok($elt, "add without optional field");
ok($dq->lock($elt), "lock");
my $hash = $dq->get($elt);
is($hash->{body}, "required only", "mandatory field present");
ok(!exists($hash->{notes}), "optional field absent");
$dq->unlock($elt);

# add with optional field
$elt = $dq->add(body => "with notes", notes => "some notes");
ok($elt, "add with optional field");
ok($dq->lock($elt), "lock");
$hash = $dq->get($elt);
is($hash->{body}, "with notes", "mandatory field present");
is($hash->{notes}, "some notes", "optional field present");
$dq->unlock($elt);

#
# Binary schema type
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q16",
    schema => { data => "binary" },
);
my $binary = "\x00\x01\x02\xff";
$elt = $dq->add(data => $binary);
ok($dq->lock($elt), "lock binary element");
$hash = $dq->get($elt);
is($hash->{data}, $binary, "binary data round-trip");
$dq->remove($elt);

#
# Purge with maxtemp=0 and maxlock=0 (disabled)
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q17",
    schema => { body => "string" },
);
$elt = $dq->add(body => "purge test");
$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ };
    $dq->purge(maxtemp => 0, maxlock => 0);
}
is($tmp, 0, "purge with disabled options is silent");
is($dq->count(), 1, "element preserved after no-op purge");

#
# Purge invalid options
#

eval { $dq->purge(bogus => 1) };
like($@, qr/unexpected option/, "purge with unexpected option dies");

eval { $dq->purge(maxtemp => "abc") };
like($@, qr/invalid maxtemp/, "purge with invalid maxtemp dies");

#
# Count on empty Normal queue
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q18",
    schema => { body => "string" },
);
is($dq->count(), 0, "count on empty Normal queue");

#
# Multiple elements with iteration
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q19",
    schema => { body => "string" },
);
$dq->add(body => "first");
$dq->add(body => "second");
$dq->add(body => "third");

my @elements;
for ($elt = $dq->first(); $elt; $elt = $dq->next()) {
    push @elements, $elt;
}
is(scalar(@elements), 3, "iterating 3 elements");
is($dq->count(), 3, "count confirms 3 elements");
