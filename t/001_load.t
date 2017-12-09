# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'Test::Against::Blead' ); }

my $object = Test::Against::Blead->new ();
isa_ok ($object, 'Test::Against::Blead');


