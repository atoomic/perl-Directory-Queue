#+##############################################################################
#                                                                              #
# File: t/1normal-validate.t                                                   #
#                                                                              #
# Description: test element name validation in Directory::Queue::Normal       #
#                                                                              #
#-##############################################################################

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 7;
use Directory::Queue::Normal;

my $tmpdir = tempdir(CLEANUP => 1);
my $schema = { body => "string" };
my $dq = Directory::Queue::Normal->new(path => "$tmpdir/validate", schema => $schema);

# add an element so we have a valid name to work with
my $valid_name = $dq->add(body => "test data");
ok($valid_name, "added a valid element");

# --- Test that touch() now validates element names ---
# (this was previously missing validation)

my @invalid_names = (
    "../../etc/passwd",
    "../secret",
    "not_hex/not_hex",
    "",
    "00000000/../00000000000000",
);

for my $bad_name (@invalid_names) {
    eval { $dq->touch($bad_name) };
    ok($@, "touch() rejects invalid element: '$bad_name'");
}

# --- Valid touch should work ---

$dq->lock($valid_name);
eval { $dq->touch($valid_name) };
ok(!$@, "touch() accepts valid element name");
$dq->remove($valid_name);
