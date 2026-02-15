#!perl

use strict;
use warnings;
use Directory::Queue::Set qw();
use Test::More tests => 5;

#
# Test that Set->new() and Set->add() properly reject non-Directory::Queue
# objects, including unblessed references which previously caused
# "Can't call method 'isa' on unblessed reference" instead of the
# expected error message.
#

# unblessed hash reference — should produce a clean error, not a crash
eval { Directory::Queue::Set->new({}) };
like($@, qr/not a Directory::Queue/, "new() rejects unblessed hashref");

# unblessed array reference
eval { Directory::Queue::Set->new([]) };
like($@, qr/not a Directory::Queue/, "new() rejects unblessed arrayref");

# scalar reference
eval { Directory::Queue::Set->new(\"foo") };
like($@, qr/not a Directory::Queue/, "new() rejects scalar ref");

# plain string — not a reference at all
eval { Directory::Queue::Set->new("not_a_queue") };
like($@, qr/not a Directory::Queue/, "new() rejects plain string");

# add() method with unblessed reference
my $set = Directory::Queue::Set->new();
eval { $set->add({}) };
like($@, qr/not a Directory::Queue/, "add() rejects unblessed hashref");
