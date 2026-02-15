#!perl

use strict;
use warnings;
use Test::More tests => 3;

use Directory::Queue::Null;

my $dq = Directory::Queue::Null->new();

# get(), get_ref(), get_path() should die
eval { $dq->get("something") };
like($@, qr/unsupported method: get/, "get dies");

eval { $dq->get_ref("something") };
like($@, qr/unsupported method: get_ref/, "get_ref dies");

eval { $dq->get_path("something") };
like($@, qr/unsupported method: get_path/, "get_path dies");
