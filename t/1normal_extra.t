#!perl

use strict;
use warnings;
use Directory::Queue::Normal qw();
use File::Temp qw(tempdir);
use Test::More tests => 35;

my ($tmpdir, $dq, $elt, %data, $ref);

$tmpdir = tempdir(CLEANUP => 1);

# --- Schema validation errors ---

# invalid schema (not a hash ref)
eval { Directory::Queue::Normal->new(path => "$tmpdir/s1", schema => "bad") };
like($@, qr/invalid schema/, "schema must be a hash ref");

eval { Directory::Queue::Normal->new(path => "$tmpdir/s2", schema => [1,2]) };
like($@, qr/invalid schema/, "schema array ref rejected");

# reserved name "locked"
eval {
    Directory::Queue::Normal->new(
        path   => "$tmpdir/s3",
        schema => { locked => "binary" },
    );
};
like($@, qr/invalid schema name/, "schema name 'locked' is reserved");

# invalid schema type
eval {
    Directory::Queue::Normal->new(
        path   => "$tmpdir/s4",
        schema => { data => "invalid_type" },
    );
};
like($@, qr/invalid schema type/, "invalid schema type rejected");

# table* is not allowed
eval {
    Directory::Queue::Normal->new(
        path   => "$tmpdir/s5",
        schema => { data => "table*" },
    );
};
like($@, qr/invalid schema type/, "table* (by reference) rejected");

# schema with no mandatory data (all optional)
eval {
    Directory::Queue::Normal->new(
        path   => "$tmpdir/s6",
        schema => { data => "string?" },
    );
};
like($@, qr/no mandatory data/, "schema with all optional fields rejected");

# --- Valid schema variations ---

# binary* (by reference)
$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/v1",
    schema => { payload => "binary*" },
);
my $bindata = "binary\x00data\xff";
$elt = $dq->add({ payload => \$bindata });
ok($elt, "add with binary* succeeds");
ok($dq->lock($elt), "lock binary* element");
my $result = $dq->get($elt);
is(ref($result->{payload}), "SCALAR", "get binary* returns scalar ref");
is(${$result->{payload}}, "binary\x00data\xff", "binary* data roundtrips correctly");
$dq->remove($elt);

# string* (by reference)
$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/v2",
    schema => { text => "string*" },
);
my $strdata = "hello unicode \x{263A}";
$elt = $dq->add({ text => \$strdata });
ok($elt, "add with string* succeeds");
ok($dq->lock($elt), "lock string* element");
$result = $dq->get($elt);
is(ref($result->{text}), "SCALAR", "get string* returns scalar ref");
is(${$result->{text}}, "hello unicode \x{263A}", "string* data roundtrips correctly");
$dq->remove($elt);

# optional fields
$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/v3",
    schema => { body => "string", header => "table?" },
);
$elt = $dq->add({ body => "minimal" });
ok($elt, "add without optional field succeeds");
ok($dq->lock($elt), "lock element with missing optional");
%data = $dq->get($elt);
is($data{body}, "minimal", "mandatory field present");
ok(!exists($data{header}), "optional field absent when not provided");
$dq->remove($elt);

# --- add() error: missing mandatory data ---

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/e1",
    schema => { body => "string", meta => "binary" },
);
eval { $dq->add({ body => "only body" }) };
like($@, qr/missing mandatory data/, "missing mandatory field dies");

# --- add() error: unexpected data field ---

eval { $dq->add({ body => "text", meta => "bin", extra => "nope" }) };
like($@, qr/unexpected data/, "unexpected data field dies");

# --- add() error: wrong ref type for non-ref schema ---

eval { $dq->add({ body => \"should not be ref", meta => "bin" }) };
like($@, qr/unexpected string data/, "ref where scalar expected dies");

# --- add() error: wrong type for table field ---

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/e2",
    schema => { body => "string", meta => "table" },
);
eval { $dq->add({ body => "text", meta => "not a hash" }) };
like($@, qr/unexpected table data/, "non-hash for table field dies");

# --- get() without schema ---

$dq = Directory::Queue::Normal->new(path => "$tmpdir/e3");
eval { $dq->get("00000000/00000000000000") };
like($@, qr/unknown schema/, "get without schema dies");

# --- add() without schema ---

eval { $dq->add({ foo => "bar" }) };
like($@, qr/unknown schema/, "add without schema dies");

# --- remove() without lock ---

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/e4",
    schema => { body => "string" },
);
$elt = $dq->add({ body => "test" });
eval { $dq->remove($elt) };
like($@, qr/not locked/, "remove without lock dies");
# clean up: lock and remove
$dq->lock($elt);
$dq->remove($elt);

# --- lock/unlock with invalid element names ---

eval { $dq->lock("invalid_name") };
like($@, qr/invalid element/, "lock with invalid element name dies");

eval { $dq->unlock("invalid_name") };
like($@, qr/invalid element/, "unlock with invalid element name dies");

# --- lock permissive mode ---

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/e5",
    schema => { body => "string" },
);
$elt = $dq->add({ body => "perm test" });
ok($dq->lock($elt), "first lock succeeds");
is($dq->lock($elt), 0, "second lock (permissive) returns 0");
$dq->unlock($elt);

# --- unlock permissive mode ---

is($dq->unlock($elt, 1), 0, "unlock permissive on unlocked returns 0");

# --- maxelts option ---

$dq = Directory::Queue::Normal->new(
    path    => "$tmpdir/e6",
    schema  => { body => "string" },
    maxelts => 2,
);
for (1..3) {
    $dq->add({ body => "element $_" });
}
is($dq->count(), 3, "3 elements with maxelts=2");
# with maxelts=2, at least 2 intermediate dirs should exist
my @dirs = grep { /^[0-9a-f]{8}$/ } do {
    opendir(my $d, "$tmpdir/e6") or die $!;
    my @e = readdir($d);
    closedir($d);
    @e;
};
cmp_ok(scalar(@dirs), ">=", 2, "maxelts=2 creates multiple intermediate dirs");

# --- invalid maxelts ---

eval { Directory::Queue::Normal->new(path => "$tmpdir/e7", schema => { b => "string" }, maxelts => 0) };
like($@, qr/invalid maxelts/, "maxelts=0 rejected");

eval { Directory::Queue::Normal->new(path => "$tmpdir/e8", schema => { b => "string" }, maxelts => "abc") };
like($@, qr/invalid maxelts/, "non-numeric maxelts rejected");

# --- unexpected option ---

eval { Directory::Queue::Normal->new(path => "$tmpdir/e9", schema => { b => "string" }, bogus => 1) };
like($@, qr/unexpected option/, "unexpected option dies");
