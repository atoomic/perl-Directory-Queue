#!perl

use strict;
use warnings;
use Directory::Queue::Normal qw();
use File::Temp qw(tempdir);
use Test::More tests => 14;

my ($tmpdir, $dq, $elt, $count);

$tmpdir = tempdir(CLEANUP => 1);

# --- purge removes stale locks ---

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/p1",
    schema => { body => "string" },
);

$elt = $dq->add({ body => "to be locked and aged" });
ok($dq->lock($elt), "lock for purge test");

# age the element directory to simulate a stale lock
my $elem_path = "$tmpdir/p1/$elt";
my $old_time = time() - 1000;
utime($old_time, $old_time, $elem_path) or die "cannot utime: $!";

my $warn_count = 0;
{
    local $SIG{__WARN__} = sub { $warn_count++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxlock => 5);
}
is($warn_count, 1, "purge warned about stale lock");
# element should now be unlocked
# try to lock it again
ok($dq->lock($elt), "can re-lock after purge unlocked stale lock");
$dq->remove($elt);

# --- purge with maxlock=0 does not unlock ---

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/p2",
    schema => { body => "string" },
);

$elt = $dq->add({ body => "should stay locked" });
ok($dq->lock($elt), "lock element");

# age it
$elem_path = "$tmpdir/p2/$elt";
$old_time = time() - 1000;
utime($old_time, $old_time, $elem_path) or die "cannot utime: $!";

$warn_count = 0;
{
    local $SIG{__WARN__} = sub { $warn_count++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxlock => 0);
}
is($warn_count, 0, "purge with maxlock=0 does not warn about locks");
# should still be locked (can't re-lock)
is($dq->lock($elt), 0, "element still locked after purge maxlock=0");
$dq->unlock($elt);
$dq->lock($elt);
$dq->remove($elt);

# --- purge removes old temporary elements ---

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/p3",
    schema => { body => "string" },
);

# create a fake temporary directory (simulating incomplete add)
my $temp_dir = "$tmpdir/p3/temporary";
my $fake_temp = "$temp_dir/" . sprintf("%08x%05x%01x", time()-2000, 0, 0);
mkdir($fake_temp) or die "cannot mkdir $fake_temp: $!";
# age it
$old_time = time() - 1000;
utime($old_time, $old_time, $fake_temp) or die "cannot utime: $!";

$warn_count = 0;
{
    local $SIG{__WARN__} = sub { $warn_count++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxtemp => 5);
}
is($warn_count, 1, "purge warned about old temp element");
ok(!-d $fake_temp, "old temp element removed");

# --- purge with maxtemp=0 does not remove temps ---

$fake_temp = "$temp_dir/" . sprintf("%08x%05x%01x", time()-2000, 0, 1);
mkdir($fake_temp) or die "cannot mkdir $fake_temp: $!";
$old_time = time() - 1000;
utime($old_time, $old_time, $fake_temp) or die "cannot utime: $!";

$warn_count = 0;
{
    local $SIG{__WARN__} = sub { $warn_count++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxtemp => 0);
}
is($warn_count, 0, "purge with maxtemp=0 does not warn about temps");

# --- purge removes empty intermediate dirs ---

$dq = Directory::Queue::Normal->new(
    path   => "$tmpdir/p4",
    schema => { body => "string" },
);

# add elements to create intermediate dirs, then remove them
for my $i (1..3) {
    $dq->add({ body => "element $i" });
}
my $initial_count = $dq->count();
is($initial_count, 3, "3 elements added");

# remove all elements
for ($elt = $dq->first(); $elt; $elt = $dq->next()) {
    $dq->lock($elt) and $dq->remove($elt);
}
is($dq->count(), 0, "all elements removed");

# purge should clean up empty intermediate dirs
$dq->purge();
# count intermediate dirs (8-hex pattern)
my @dirs = grep { /^[0-9a-f]{8}$/ } do {
    opendir(my $d, "$tmpdir/p4") or die $!;
    my @e = readdir($d);
    closedir($d);
    @e;
};
# at most 1 intermediate dir should remain (the last one is kept)
cmp_ok(scalar(@dirs), "<=", 1, "purge cleaned up empty intermediate dirs");

# --- purge with invalid options ---

eval { $dq->purge(bogus => 42) };
like($@, qr/unexpected option/, "purge with unexpected option dies");

eval { $dq->purge(maxtemp => "abc") };
like($@, qr/invalid maxtemp/, "purge with non-numeric maxtemp dies");
