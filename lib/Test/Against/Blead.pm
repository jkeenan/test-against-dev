package Test::Against::Blead;
use strict;
our $VERSION = '0.01';
use Carp;

sub new {
    my ($class, $args) = @_;
    $args //= {};

    croak "Argument to constructor must be hashref"
        unless ref($args) eq 'HASH';

    my $data = {};

    return bless $data, $class;
}


1;

