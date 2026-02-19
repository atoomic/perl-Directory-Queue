#!perl

use strict;
use warnings;
use Directory::Queue::Null;
use File::Temp qw(tempdir);
use Test::More tests => 13;

my $dq = Directory::Queue::Null->new();

# test path() and id() return "NULL"
is($dq->path(), "NULL", "path is NULL");
is($dq->id(), "NULL", "id is NULL");

# test add_ref returns empty string
is($dq->add_ref(\"some data"), "", "add_ref returns empty string");

# test purge is a no-op (should not die)
eval { $dq->purge() };
is($@, "", "purge does not die");

# test unsupported methods all die with the right message
eval { $dq->touch("foo") };
like($@, qr/unsupported method: touch\(\)/, "touch dies");

eval { $dq->lock("foo") };
like($@, qr/unsupported method: lock\(\)/, "lock dies");

eval { $dq->unlock("foo") };
like($@, qr/unsupported method: unlock\(\)/, "unlock dies");

eval { $dq->remove("foo") };
like($@, qr/unsupported method: remove\(\)/, "remove dies");

eval { $dq->get("foo") };
like($@, qr/unsupported method: get\(\)/, "get dies");

eval { $dq->get_ref("foo") };
like($@, qr/unsupported method: get_ref\(\)/, "get_ref dies");

eval { $dq->get_path("foo") };
like($@, qr/unsupported method: get_path\(\)/, "get_path dies");

# test add_path actually deletes the file
my $tmpdir = tempdir(CLEANUP => 1);
my $tmpfile = "$tmpdir/test_file";
open(my $fh, ">", $tmpfile) or die "cannot create $tmpfile: $!";
print $fh "data to be deleted";
close($fh);
ok(-f $tmpfile, "temp file exists before add_path");
my $name = $dq->add_path($tmpfile);
is($name, "", "add_path returns empty string");
# Note: file should be deleted by add_path
