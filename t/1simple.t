#!perl

use strict;
use warnings;
use Directory::Queue::Simple qw();
use File::Temp qw(tempdir);
use No::Worries::Dir qw(dir_read);
use Test::More tests => 22;

our($tmpdir, $dq, $elt, @list, $time, $tmp);

$tmpdir = tempdir(CLEANUP => 1);

@list = dir_read($tmpdir);
is(scalar(@list), 0, "temp directory starts empty");

$dq = Directory::Queue::Simple->new(path => $tmpdir);
is(scalar(@list), 0, "new queue has no intermediate dirs");

# Add first element and verify directory structure
$elt = $dq->add("hello world");
@list = dir_read($tmpdir);
is(scalar(@list), 1, "one intermediate dir created after add");
like($list[0], qr/^[0-9a-f]{8}$/, "intermediate dir is 8-hex name");
@list = dir_read("$tmpdir/$list[0]");
is(scalar(@list), 1, "one element file in intermediate dir");
like($list[0], qr/^[0-9a-f]{14}$/, "element file is 14-hex name");
is($dq->count(), 1, "count is 1 after first add");

# Lock, get, unlock cycle
$elt = $dq->first();
ok($dq->lock($elt), "lock element");
$tmp = $dq->get($elt);
is($tmp, "hello world", "get returns stored data");
$tmp = $dq->get_ref($elt);
is(${$tmp}, "hello world", "get_ref returns reference to stored data");
ok($dq->unlock($elt), "unlock element");

# Add more elements
foreach (1 .. 12) {
    $elt = $dq->add($_);
}
is($dq->count(), 13, "count is 13 after adding 12 more");

# Iterator
$elt = $dq->first();
ok($elt, "first() returns an element");
$elt = $dq->next();
ok($elt, "next() returns an element");

# Remove locked element
ok($dq->lock($elt), "lock for removal");
eval { $dq->remove($elt) };
is($@, "", "remove locked element succeeds");
is($dq->count(), 12, "count is 12 after removing one");

# Remove unlocked element fails
$elt = $dq->next();
eval { $dq->remove($elt) };
ok($@, "remove unlocked element dies");

# Remove all elements
for ($elt = $dq->first(); $elt; $elt = $dq->next()) {
    $dq->lock($elt) and $dq->remove($elt);
}
is($dq->count(), 0, "count is 0 after removing all elements");

# Purge stale .tmp file
$elt = $dq->add("dummy");
$tmp = "$tmpdir/$elt.tmp";
rename("$tmpdir/$elt", $tmp) or die("cannot rename($tmpdir/$elt, $tmp): $!\n");
is($dq->count(), 0, "renamed-to-.tmp element not counted");
$time = time() - 1000;
utime($time, $time, $tmp) or die("cannot utime($time, $time, $tmp): $!\n");
$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ if $_[0] =~ /removing too old/ };
    $dq->purge(maxtemp => 5);
}
is($tmp, 1, "purge removes stale .tmp file");
$elt =~ s/\/.+//;
@list = dir_read("$tmpdir/$elt");
is(scalar(@list), 0, "intermediate dir is empty after purge");
