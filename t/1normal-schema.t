#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 31;

use Directory::Queue::Normal;

our($tmpdir, $dq, $elt, $hash);

$tmpdir = tempdir(CLEANUP => 1);

#
# String reference schema (string*)
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q1",
    schema => { body => "string*" },
);

my $str = "hello by ref";
$elt = $dq->add(body => \$str);
ok($elt, "add string by reference");
ok($dq->lock($elt), "lock");
$hash = $dq->get($elt);
is(ref($hash->{body}), "SCALAR", "get string by reference returns SCALAR ref");
is(${ $hash->{body} }, "hello by ref", "string ref content matches");
$dq->remove($elt);

# Error: pass non-ref for string* schema
eval { $dq->add(body => "not a reference") };
like($@, qr/unexpected/, "string* rejects non-reference");

#
# Binary reference schema (binary*)
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q2",
    schema => { data => "binary*" },
);

my $bin = "\x00\xff\x80";
$elt = $dq->add(data => \$bin);
ok($elt, "add binary by reference");
ok($dq->lock($elt), "lock");
$hash = $dq->get($elt);
is(ref($hash->{data}), "SCALAR", "get binary by reference returns SCALAR ref");
is(${ $hash->{data} }, "\x00\xff\x80", "binary ref content matches");
$dq->remove($elt);

# Error: pass non-ref for binary*
eval { $dq->add(data => "not a reference") };
like($@, qr/unexpected/, "binary* rejects non-reference");

#
# Table data type
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q3",
    schema => { meta => "table" },
);

my %table = (key1 => "value1", key2 => "value2");
$elt = $dq->add(meta => \%table);
ok($elt, "add table data");
ok($dq->lock($elt), "lock");
$hash = $dq->get($elt);
is(ref($hash->{meta}), "HASH", "table returns HASH ref");
is($hash->{meta}{key1}, "value1", "table key1 matches");
is($hash->{meta}{key2}, "value2", "table key2 matches");
$dq->remove($elt);

# Error: table expects hashref, not scalar
eval { $dq->add(meta => "not a hash") };
like($@, qr/unexpected/, "table rejects scalar data");

# Error: table expects hashref, not scalar ref
eval { $dq->add(meta => \"ref to scalar") };
like($@, qr/unexpected/, "table rejects scalar ref");

#
# Table with special characters (escape handling)
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q4",
    schema => { meta => "table" },
);

my %special = (
    "key\twith\ttabs"       => "val\twith\ttabs",
    "key\nwith\nnewlines"   => "val\nwith\nnewlines",
    "key\\with\\backslashes" => "val\\with\\backslashes",
);
$elt = $dq->add(meta => \%special);
ok($dq->lock($elt), "lock special chars");
$hash = $dq->get($elt);
is($hash->{meta}{"key\twith\ttabs"}, "val\twith\ttabs", "tab escaping roundtrip");
is($hash->{meta}{"key\nwith\nnewlines"}, "val\nwith\nnewlines", "newline escaping roundtrip");
is($hash->{meta}{"key\\with\\backslashes"}, "val\\with\\backslashes", "backslash escaping roundtrip");
$dq->remove($elt);

#
# Table with undefined value (should die)
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q5",
    schema => { meta => "table" },
);
eval { $dq->add(meta => { key => undef }) };
like($@, qr/undefined hash value/, "table with undef value dies");

#
# Table with reference value (should die)
#

eval { $dq->add(meta => { key => [1,2,3] }) };
like($@, qr/invalid hash scalar/, "table with array ref value dies");

#
# Mixed mandatory and optional fields
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q6",
    schema => { body => "string", extra => "binary?", meta => "table?" },
);

# Mandatory only
$elt = $dq->add(body => "just body");
ok($elt, "add mandatory only");
ok($dq->lock($elt), "lock");
$hash = $dq->get($elt);
is($hash->{body}, "just body", "mandatory field present");
ok(!exists($hash->{extra}), "optional binary absent");
ok(!exists($hash->{meta}), "optional table absent");
$dq->remove($elt);

# All fields
$elt = $dq->add(body => "full", extra => "bin", meta => { k => "v" });
ok($dq->lock($elt), "lock full");
$hash = $dq->get($elt);
is($hash->{body}, "full", "mandatory field");
is($hash->{extra}, "bin", "optional binary field");
$dq->remove($elt);
