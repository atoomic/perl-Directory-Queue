#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 18;

use Directory::Queue::Null;

our($tmpdir, $dq);

$tmpdir = tempdir(CLEANUP => 1);

$dq = Directory::Queue::Null->new();

# Basic properties
is($dq->path(), "NULL", "path is NULL");
is($dq->id(), "NULL", "id is NULL");

# Iteration always empty
is($dq->first(), "", "first returns empty string");
is($dq->next(), "", "next returns empty string");
is($dq->count(), 0, "count is always 0");

# add() accepts anything and returns empty string
is($dq->add("some data"), "", "add scalar returns empty string");
is($dq->add({ key => "value" }), "", "add hashref returns empty string");
is($dq->add(1, 2, 3), "", "add list returns empty string");

# add_ref() returns empty string
my $data = "reference data";
is($dq->add_ref(\$data), "", "add_ref returns empty string");

# add_path() removes the file and returns empty string
my $path = "$tmpdir/testfile";
open(my $fh, ">", $path) or die "cannot create $path: $!";
print $fh "test content";
close($fh);
ok(-f $path, "test file exists before add_path");
is($dq->add_path($path), "", "add_path returns empty string");
ok(!-f $path, "test file removed after add_path");

# purge() does nothing (no error)
eval { $dq->purge() };
is($@, "", "purge succeeds silently");

# count is still 0 after adds
is($dq->count(), 0, "count still 0 after adds");

# Unsupported methods die
eval { $dq->touch("something") };
like($@, qr/unsupported method: touch/, "touch dies");

eval { $dq->lock("something") };
like($@, qr/unsupported method: lock/, "lock dies");

eval { $dq->unlock("something") };
like($@, qr/unsupported method: unlock/, "unlock dies");

eval { $dq->remove("something") };
like($@, qr/unsupported method: remove/, "remove dies");
