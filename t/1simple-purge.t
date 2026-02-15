#!perl

use strict;
use warnings;
use Directory::Queue::Simple qw();
use File::Temp qw(tempdir);
use Test::More tests => 4;

#
# Test that Simple::purge() correctly uses maxlock (not maxtemp) as the
# default for the maxlock option.
#
# Bug: purge() had "$self->{maxtemp}" where it should have "$self->{maxlock}"
# causing locked elements to be purged using the maxtemp timeout (300s)
# instead of the maxlock timeout (600s).
#

my $tmpdir = tempdir(CLEANUP => 1);

# create a queue with very different maxlock and maxtemp values
# so we can detect which one is used
my $dq = Directory::Queue::Simple->new(
    path    => $tmpdir,
    maxlock => 900,   # 15 minutes
    maxtemp => 100,   # ~1.5 minutes
);

is($dq->{maxlock}, 900, "maxlock stored correctly");
is($dq->{maxtemp}, 100, "maxtemp stored correctly");

# add an element, lock it, then backdate the lock file
my $elt = $dq->add("test data");
ok($dq->lock($elt), "lock element");

# backdate the element to 200 seconds ago
# this is older than maxtemp (100) but younger than maxlock (900)
my $time = time() - 200;
my $path = "$tmpdir/$elt";
utime($time, $time, $path) or die("cannot utime: $!\n");
my $lock = $path . ".lck";
utime($time, $time, $lock) or die("cannot utime lock: $!\n");

# purge with defaults — if maxlock is correctly used (900s),
# this lock should NOT be purged (200 < 900)
# if the bug is present (maxtemp=100 used instead), it WOULD be purged
my $warnings = 0;
{
    local $SIG{__WARN__} = sub { $warnings++ if $_[0] =~ /removing too old/ };
    $dq->purge();
}
is($warnings, 0, "purge() uses maxlock (not maxtemp) for lock timeout");
