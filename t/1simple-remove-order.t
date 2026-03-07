#!perl

use strict;
use warnings;
use Directory::Queue::Simple qw();
use File::Temp qw(tempdir);
use Test::More tests => 6;

my $tmpdir = tempdir(CLEANUP => 1);
my $dq = Directory::Queue::Simple->new(path => $tmpdir);

# add an element, lock it, then remove it
my $elt = $dq->add("test data");
ok($dq->lock($elt), "lock element");

my $data_path = "$tmpdir/$elt";
my $lock_path = "$tmpdir/$elt.lck";

ok(-f $data_path, "data file exists before remove");
ok(-f $lock_path, "lock file exists before remove");

eval { $dq->remove($elt) };
is($@, "", "remove succeeds");

ok(! -e $lock_path, "lock file removed after remove");
ok(! -e $data_path, "data file removed after remove");
