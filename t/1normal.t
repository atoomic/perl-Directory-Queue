#!perl

use strict;
use warnings;
use Encode;
use Directory::Queue::Normal qw();
use File::Temp qw(tempdir);
use No::Worries::Dir qw(dir_read);
use No::Worries::File qw(file_read);
use POSIX qw(:errno_h :fcntl_h);
use Test::More tests => 49;

use constant STR_ISO8859 => "Th\xe9\xe2tre Fran\xe7ais";
use constant STR_UNICODE => "is \x{263A}?";

our($tmpdir, $dq, $elt, @list, $time, $tmp);

sub test_field ($$$) {
    my($field, $tag, $exp) = @_;
    my($hash);

    $dq->lock($elt);
    $hash = $dq->get($elt);
    $dq->unlock($elt);
    if ($dq->{ref}{$field}) {
        is(${ $hash->{$field} }, $exp, "$field $tag (get by reference)");
    } else {
        is($hash->{$field}, $exp, "$field $tag (get)");
    }
    if ($dq->{type}{$field} eq "binary") {
        is(file_read("$tmpdir/$elt/$field"), $exp, "$field $tag (file)");
    } elsif ($dq->{type}{$field} eq "string") {
        is(file_read("$tmpdir/$elt/$field"), encode("UTF-8", $exp), "$field $tag (file)");
    } else {
        fail("unexpected field type: $dq->{type}{$field}");
    }
}

$tmpdir = tempdir(CLEANUP => 1);
#diag("Using temporary directory $tmpdir");

@list = dir_read($tmpdir);
is(scalar(@list), 0, "empty directory");

$dq = Directory::Queue::Normal->new(path => $tmpdir, schema => { string => "string" });
@list = sort(dir_read($tmpdir));
is("@list", "obsolete temporary", "empty queue");

$elt = $dq->add(string => STR_ISO8859);
@list = sort(dir_read($tmpdir));
is("@list", "00000000 obsolete temporary", "non-empty queue");
@list = dir_read("$tmpdir/00000000");
is("00000000/@list", $elt, "one element");
test_field("string", "ISO-8859-1", STR_ISO8859);
is($dq->count(), 1, "count 1");

$elt = $dq->add(string => STR_UNICODE);
test_field("string", "Unicode", STR_UNICODE);
is($dq->count(), 2, "count 2");

$elt = $dq->first();
ok($elt, "first() returns an element");
ok(!$dq->_is_locked($elt), "new element is not locked");
ok($dq->lock($elt), "lock() succeeds");
ok( $dq->_is_locked($elt), "element is locked after lock()");
ok($dq->unlock($elt), "unlock() succeeds");
ok(!$dq->_is_locked($elt), "element is unlocked after unlock()");

$elt = $dq->next();
ok($elt, "next() returns an element");
ok($dq->lock($elt), "lock second element");
eval { $dq->remove($elt) };
is($@, "", "remove locked element succeeds");
is($dq->count(), 1, "count is 1 after removing one of two");

$elt = $dq->first();
ok($elt, "first() still returns remaining element");
eval { $dq->remove($elt) };
like($@, qr/not locked/, "remove unlocked element dies");
ok($dq->lock($elt), "lock remaining element");
eval { $dq->remove($elt) };
is($@, "", "remove last locked element succeeds");
is($dq->count(), 0, "count is 0 after removing all");

$dq = Directory::Queue::Normal->new(path => $tmpdir, schema => { binary => "binary" });
$elt = $dq->add(binary => STR_ISO8859);
test_field("binary", "ISO-8859-1", STR_ISO8859);

$tmp = "foobar";
$dq = Directory::Queue::Normal->new(path => $tmpdir, schema => { binary => "binary*" });
eval { $elt = $dq->add(binary => $tmp) };
like($@, qr/unexpected/, "add scalar to binary* field dies (expects reference)");
eval { $elt = $dq->add(binary => \$tmp) };
is($@, "", "add reference to binary* field succeeds");
test_field("binary", "by reference", $tmp);

$tmp = $dq->count();
$dq = Directory::Queue::Normal->new(path => $tmpdir, schema => { string => "binary" }, maxelts => $tmp);
@list = sort(dir_read($tmpdir));
is("@list", "00000000 obsolete temporary", "one intermediate dir before overflow");
$elt = $dq->add(string => $tmp);
@list = sort(dir_read($tmpdir));
is("@list", "00000000 00000001 obsolete temporary", "new intermediate dir created when maxelts reached");

# Purge test: age two locked elements, touch one, purge should only unlock the untouched one
$time = time() - 10;
$elt = $dq->first();
$dq->lock($elt);
$tmp = $dq->path() . "/" . $elt;
utime($time, $time, $tmp) or die("cannot utime($time, $time, $tmp): $!\n");
$elt = $dq->next();
$dq->lock($elt);
$tmp = $dq->path() . "/" . $elt;
utime($time, $time, $tmp) or die("cannot utime($time, $time, $tmp): $!\n");
$elt = $dq->first();
$dq->touch($elt);
$tmp = 0;
{
    local $SIG{__WARN__} = sub { $tmp++ if $_[0] =~ /removing too old locked/ };
    $dq->purge(maxlock => 5);
}
is($tmp, 1, "purge unlocks one stale lock (touched element kept)");
$elt = $dq->first();
$elt = $dq->next();
ok($dq->lock($elt), "purged element can be re-locked");
is($dq->count(), 3, "count unchanged after purge (elements still exist)");

$dq = Directory::Queue::Normal->new(path => $tmpdir, schema => { string => "binary", optional => "string?" });
ok($dq->add(string => "add by hash"), "add() with hash args (mandatory only)");
ok($dq->add(string => "add by hash", optional => "yes"), "add() with hash args (mandatory + optional)");
ok($dq->add({string => "add by hash ref"}), "add() with hashref (mandatory only)");
ok($dq->add({string => "add by hash ref", optional => "yes"}), "add() with hashref (mandatory + optional)");

$elt = $dq->add(string => "foo", optional => "bar");
eval { @list = $dq->get($elt) };
like($@, qr/not locked/, "get() on unlocked element dies");
ok($dq->lock($elt), "lock for get test");
eval { @list = $dq->get($elt) };
is($@, "", "get() in list context succeeds");
is(scalar(@list), 4, "get() returns 4 items (2 key-value pairs)");
eval { $tmp = $dq->get($elt) };
is($@, "", "get() in scalar context succeeds");
is(ref($tmp), "HASH", "get() in scalar context returns hashref");

$dq = Directory::Queue::Normal->new(path => $tmpdir);
$tmp = 0;
for ($elt = $dq->first(); $elt; $elt = $dq->next()) {
    $tmp++;
}
is($dq->count(), $tmp, "count() matches iterator traversal");
for ($elt = $dq->first(); $elt; $elt = $dq->next()) {
    $dq->lock($elt); # don't care if failed...
    $dq->remove($elt);
}
is($dq->count(), 0, "queue empty after removing all elements");
$dq->purge();
@list = sort(dir_read($tmpdir));
is("@list", "00000001 obsolete temporary", "purge cleaned empty intermediate dirs");
