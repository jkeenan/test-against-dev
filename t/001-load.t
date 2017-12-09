# -*- perl -*-
# t/001-load.t - check module loading and create testing directory
use strict;
use warnings;

use Test::More tests => 2;

BEGIN { use_ok( 'Test::Against::Blead' ); }

my $self = Test::Against::Blead->new ();
isa_ok ($self, 'Test::Against::Blead');


