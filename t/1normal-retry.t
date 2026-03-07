#!perl

use strict;
use warnings;
use Directory::Queue::Normal qw();
use File::Temp qw(tempdir);
use No::Worries::Dir qw(dir_read);
use Test::More tests => 4;

my($tmpdir, $dq, $elt);

$tmpdir = tempdir(CLEANUP => 1);

# verify the retry constants are defined and sensible
ok(Directory::Queue::Normal::REMOVE_MAX_RETRIES > 0,
    "REMOVE_MAX_RETRIES is positive");
ok(Directory::Queue::Normal::REMOVE_BACKOFF_USEC > 0,
    "REMOVE_BACKOFF_USEC is positive");

# verify remove still works normally (regression)
$dq = Directory::Queue::Normal->new(path => $tmpdir, schema => { body => "string" });
$elt = $dq->add(body => "test element");
ok($dq->lock($elt), "lock for remove");
eval { $dq->remove($elt) };
is($@, "", "remove succeeds normally with retry logic");
