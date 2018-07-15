package Test::Against::Dev::ProcessPSV;
use strict;
use 5.14.0;
our $VERSION = '0.09';
use Carp;
use Data::Dump ( qw| dd pp | );
use Text::CSV_XS;

=head1 NAME

Test::Against::Dev::ProcessPSV - Process monthly and master PSV files

=head1 SYNOPSIS

    use Test::Against::Dev::ProcessPSV;

    my $ppsv = Test::Against::Dev::ProcessPSV( {
        verbose =>1,
    } );

    my $columns_seen = $ppsv->read_one_psv( {
        psvfile => '/path/to/psvfile',
    } );

    my $master_columns_ref = [
      "dist",
      "perl-5.29.0.author",
      "perl-5.29.0.distname",
      "perl-5.29.0.distversion",
      "perl-5.29.0.grade",
      "perl-5.29.1.author",
      "perl-5.29.1.distname",
      "perl-5.29.1.distversion",
      "perl-5.29.1.grade",
      ...
    ];

    my $rv = $ppsv->write_master_psv( {
        master_columns  => $master_columns_ref,
        master_psvfile  => '/path/to/master_psvfile',
    );

=cut

=head1 DESCRIPTION

This module provides methods for processing data stored in PSV (C<.psv>) files
generated by the F<Test::Against::Dev> and F<Test::Against::Commit> packages
included in this CPAN distribution.

=head1 METHODS

=head2 C<new()>

=over 4

=item * Purpose

Test::Against::Dev::ProcessPSV constructor.

=item * Arguments

    my $ppsv = Test::Against::Dev::ProcessPSV( { verbose =>1 } );

Hash reference.  Currently optional, as only element currently possible in
that hash is C<verbose>, which is off by default.

=item * Return Value

Test::Against::Dev::ProcessPSV object.

=back

=cut

sub new {
    my ($class, $args) = @_;
    if (! $args) {
        return bless {}, $class;
    }
    croak "Argument to constructor must be hashref"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';

    my $data = {};
    $data->{verbose} = $verbose;
    $data->{master_data} = {};

    return bless $data, $class;
}

=head2 C<read_one_psv()>

=over 4

=item * Purpose

Create or augment a data structure holding the results of one or more test-against-dev processes.

=item * Arguments

    my $columns_seen = $ppsv->read_one_psv( {
        psvfile => '/path/to/psvfile',
    } );

Hash reference.  Element C<psvfile> is required; must be absolute path to a
PSV file generated by a test-against-dev process.  The columns in that file
must look like this:

      "dist",
      "perl-5.29.0.author",
      "perl-5.29.0.distname",
      "perl-5.29.0.distversion",
      "perl-5.29.0.grade",
      "perl-5.29.1.author",
      "perl-5.29.1.distname",
      "perl-5.29.1.distversion",
      "perl-5.29.1.grade",
      ...

The entries in the C<dist> column will be the names of CPAN distributions being tested in the test-against-dev process.

    dist|perl-5.29.0.author|perl-5.29.0.distname|perl-5.29.0.distversion|perl-5.29.0.grade
    AAAA-Crypt-DH|BINGOS|AAAA-Crypt-DH-0.06|0.06|PASS
    ARGV-Struct|JLMARTIN|ARGV-Struct-0.03|0.03|PASS
    AWS-Signature4|LDS|AWS-Signature4-1.02|1.02|PASS
    Acme-Damn|IBB|Acme-Damn-0.08|0.08|PASS
    ...

=item * Return Value

Array reference holding a list of the columns detected within the PSV file.
The number of columns must be at least 5.

=item * Comment

The method reads data from the PSV file and stores it within the object.

=back

=cut

sub read_one_psv {
    my ($self, $args) = @_;
    croak "Argument to constructor must be hashref"
        unless ref($args) eq 'HASH';
    my %eligible_args = map { $_ => 1 } ( qw| psvfile | );
    for my $k (keys %$args) {
        croak "read_one_psv: '$k' is not a valid element"
            unless $eligible_args{$k};
    }
    croak "Could not locate $args->{psvfile}" unless -f $args->{psvfile};
    say "Handling $args->{psvfile} ..." if $self->{verbose};

    my $psv = Text::CSV_XS->new({ binary => 1, auto_diag => 1, sep_char => '|', eol => $/ });
    open my $IN, "<:encoding(utf8)", $args->{psvfile}
        or croak "Unable to open $args->{psvfile} for reading";

    my @cols = @{$psv->getline($IN)};
    dd(\@cols) if $self->{verbose};
    my $row = {};
    $psv->bind_columns(\@{$row}{@cols});
    while ($psv->getline($IN)) {
        my $dist = $row->{dist};
        $self->{master_data}->{$dist}{$_} = $row->{$_} for keys %{$row};
    }
    close $IN or croak "Unable to close $args->{psvfile} after reading";
    $self->{psvfile} = $args->{psvfile};
    return \@cols;
}

=head2 C<write_master_psv()>

=over 4

=item * Purpose

=item * Arguments

    my $master_columns_ref = [
      "dist",
      "perl-5.29.0.author",
      "perl-5.29.0.distname",
      "perl-5.29.0.distversion",
      "perl-5.29.0.grade",
      "perl-5.29.1.author",
      "perl-5.29.1.distname",
      "perl-5.29.1.distversion",
      "perl-5.29.1.grade",
      ...
    ];
    my $rv = $ppsv->write_master_psv( {
        master_columns  => $master_columns_ref,
        master_psvfile  => '/path/to/master_psvfile',
    );

Hash reference, currently with 2 possible elements:

=over 4

=item * C<master_columns>

Array reference holding list of column names to be written to master PSV file.

=item 3 C<master_psvfile>

String holding absolute path to the new master PSV file to be populated with
data in object.

=back

=item * Return Value

Returns Perl-true value; dies otherwise.

=item * Comment

Writes the pipe-separated-values file specified in the third argument.

=back

=cut

sub write_master_psv {
    my ($self, $args) = @_;
    croak "Argument to write_master_psv() must be hashref"
        unless ref($args) eq 'HASH';
    my %eligible_args = map { $_ => 1 } ( qw| master_columns master_psvfile | );
    for my $k (keys %$args) {
        croak "read_one_psv: '$k' is not a valid element"
            unless $eligible_args{$k};
    }
    croak "Value for 'master_columns' must be arrayref"
        unless ref($args->{master_columns}) eq 'ARRAY';

    my $psv = Text::CSV_XS->new({ binary => 1, auto_diag => 1, sep_char => '|', eol => $/ });
    open my $OUT, ">:encoding(utf8)", $args->{master_psvfile}
        or croak "Unable to open $args->{master_psvfile} for writing";
    $psv->print($OUT, $args->{master_columns}), "\n" or $psv->error_diag;
    for my $dist (sort keys %{$self->{master_data}}) {
        my @modified_data = @{$self->{master_data}->{$dist}}{@{$args->{master_columns}}};
        ROW: for (my $i = $#modified_data; $i >= 0; $i--) {
            last ROW if length($modified_data[$i]);
            $modified_data[$i] = 'x';
        }
        $psv->print($OUT, [ @modified_data ])
            or $psv->error_diag;
    }
    close $OUT or croak "Unable to close $args->{master_psvfile} after writing";
    $self->{master_psvfile} = $args->{master_psvfile};
    return 1;
}

1;
