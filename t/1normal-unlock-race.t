#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Path qw(remove_tree);
use Test::More tests => 6;

use Directory::Queue::Normal;

my $tmpdir = tempdir(CLEANUP => 1);

#
# Test permissive unlock when element directory has been removed (race condition)
#

my $dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q1",
    schema => { body => "string" },
);
my $elt = $dq->add(body => "race test");
ok($dq->lock($elt), "lock element");

# Simulate another process removing the entire element directory
my $elt_path = "$tmpdir/q1/$elt";
remove_tree($elt_path);
ok(!-d $elt_path, "element directory removed");

# Permissive unlock should return false (ENOENT), not die
ok(!$dq->unlock($elt, 1), "permissive unlock returns false when element gone");

# Non-permissive unlock should die
$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q2",
    schema => { body => "string" },
);
$elt = $dq->add(body => "race test 2");
ok($dq->lock($elt), "lock element");

$elt_path = "$tmpdir/q2/$elt";
remove_tree($elt_path);

eval { $dq->unlock($elt, 0) };
like($@, qr/cannot rmdir/, "non-permissive unlock dies when element gone");

#
# Test permissive lock when element directory disappears during locking
# (simulate race where element is removed between mkdir check and lstat)
#

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/q3",
    schema => { body => "string" },
);
$elt = $dq->add(body => "lock race");

# Remove element to simulate race with ENOENT on mkdir
$elt_path = "$tmpdir/q3/$elt";
remove_tree($elt_path);

ok(!$dq->lock($elt, 1), "permissive lock returns false when element removed");
