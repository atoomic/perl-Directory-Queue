#+##############################################################################
#                                                                              #
# File: t/1simple-validate.t                                                   #
#                                                                              #
# Description: test element name validation in Directory::Queue::Simple       #
#                                                                              #
#-##############################################################################

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 19;
use Directory::Queue::Simple;

my $tmpdir = tempdir(CLEANUP => 1);
my $dq = Directory::Queue::Simple->new(path => "$tmpdir/validate");

# add an element so we have a valid name to work with
my $valid_name = $dq->add("test data");
ok($valid_name, "added a valid element");

# --- Invalid element names that should be rejected ---

my @invalid_names = (
    "../../etc/passwd",
    "../secret",
    "not_hex/not_hex",
    "12345678",           # directory part only, no element
    "",                   # empty string
    "/absolute/path",
    "00000000/short",     # element too short (5 chars)
    "ZZZZZZZZ/00000000000000",  # non-hex directory
    "00000000/ZZZZZZZZZZZZZZ",  # non-hex element
    "00000000/../00000000000000", # path traversal in middle
);

# Test that all invalid names die on lock()
for my $bad_name (@invalid_names) {
    eval { $dq->lock($bad_name) };
    ok($@, "lock() rejects invalid element: '$bad_name'");
}

# Test that invalid names are rejected by other methods too
eval { $dq->get("../../etc/passwd") };
ok($@, "get() rejects path traversal");

eval { $dq->get_ref("../../etc/passwd") };
ok($@, "get_ref() rejects path traversal");

eval { $dq->get_path("../../etc/passwd") };
ok($@, "get_path() rejects path traversal");

eval { $dq->unlock("../../etc/passwd") };
ok($@, "unlock() rejects path traversal");

eval { $dq->touch("../../etc/passwd") };
ok($@, "touch() rejects path traversal");

eval { $dq->remove("../../etc/passwd") };
ok($@, "remove() rejects path traversal");

# --- Valid element names should still work ---

# lock/unlock should succeed with a valid name from the iterator
ok($dq->lock($valid_name), "lock() accepts valid element name");
ok($dq->unlock($valid_name), "unlock() accepts valid element name");

# clean up
$dq->lock($valid_name);
$dq->remove($valid_name);
