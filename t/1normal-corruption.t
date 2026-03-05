#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use No::Worries::File qw(file_write);
use Test::More tests => 12;

use Directory::Queue::Normal;

my $tmpdir = tempdir(CLEANUP => 1);

#
# Test get() with missing mandatory data file (filesystem corruption)
#

my $dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q1",
    schema => { body => "string", header => "table" },
);
my $elt = $dq->add(body => "test body", header => { key => "val" });
ok($dq->lock($elt), "lock element");

# Remove the mandatory 'header' file to simulate corruption
my $header_path = "$tmpdir/q1/$elt/header";
ok(-f $header_path, "header file exists");
unlink($header_path) or die "cannot unlink: $!";

eval { $dq->get($elt) };
like($@, qr/missing data file/, "get dies on missing mandatory file");
$dq->unlock($elt, 1);

#
# Test get() with invalid UTF-8 data (decode failure)
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q2",
    schema => { body => "string" },
);
$elt = $dq->add(body => "good string");
ok($dq->lock($elt), "lock element");

# Overwrite body file with invalid UTF-8 bytes
my $body_path = "$tmpdir/q2/$elt/body";
file_write($body_path, data => "\xff\xfe\x80\x81");

eval { $dq->get($elt) };
like($@, qr/cannot UTF-8 decode/, "get dies on invalid UTF-8 in string field");
$dq->unlock($elt, 1);

#
# Test get() with corrupted table file (malformed line in _string2hash)
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q3",
    schema => { meta => "table" },
);
$elt = $dq->add(meta => { key => "value" });
ok($dq->lock($elt), "lock element");

# Overwrite the table file with a malformed line (no tab separator)
my $meta_path = "$tmpdir/q3/$elt/meta";
file_write($meta_path, data => "malformed line without tab\n");

eval { $dq->get($elt) };
like($@, qr/unexpected hash line/, "get dies on malformed table data");
$dq->unlock($elt, 1);

#
# Test add() with hash ref form (single argument)
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q4",
    schema => { body => "string" },
);

# Single hashref argument
$elt = $dq->add({ body => "via hashref" });
ok($elt, "add with hashref works");
ok($dq->lock($elt), "lock hashref element");
my $data = $dq->get($elt);
is($data->{body}, "via hashref", "get returns correct data from hashref add");
$dq->remove($elt);

#
# Test add() with wrong data type for string field (reference instead of scalar)
#

eval { $dq->add(body => ["not", "a", "string"]) };
like($@, qr/unexpected string data/, "add with array ref for string field dies");

#
# Test add() with wrong data type for table field (scalar instead of hash ref)
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q5",
    schema => { data => "table" },
);
eval { $dq->add(data => "not a hash") };
like($@, qr/unexpected table data/, "add with scalar for table field dies");
