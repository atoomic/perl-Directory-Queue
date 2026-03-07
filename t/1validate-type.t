#!perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More tests => 6;

use Directory::Queue;

my $tmpdir = tempdir(CLEANUP => 1);

# valid types
foreach my $type (qw(Simple Normal Null)) {
    my $dq = eval {
        Directory::Queue->new(path => "$tmpdir/$type", type => $type);
    };
    isa_ok($dq, "Directory::Queue", "type '$type' is accepted");
}

# invalid types that could lead to code injection
foreach my $bad_type ("Foo; system('echo pwned')", "Foo\nBar", "../Foo") {
    eval {
        Directory::Queue->new(path => "$tmpdir/bad", type => $bad_type);
    };
    like($@, qr/invalid type/, "type '$bad_type' is rejected");
}
