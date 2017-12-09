package Test::Against::Blead;
use strict;
use 5.10.1;
our $VERSION = '0.01';
use Carp;
use File::Path ( qw| make_path | );
use File::Spec;

# What args must be passed to constructor?
# application top-level directory
# Constructor will get path to top-level directory for application,
# compose names of other directories in the tree, verify they exist or create
# them as needed.

sub new {
    my ($class, $args) = @_;
    $args //= {};

    croak "Argument to constructor must be hashref"
        unless ref($args) eq 'HASH';
    croak "Hash ref must contain 'application_dir' element"
        unless $args->{application_dir};
    croak "Could not locate $args->{application_dir}"
        unless (-d $args->{application_dir});

    my $data;
    for my $k (keys %{$args}) {
        $data->{$k} = $args->{$k};
    }

    for my $dir (qw| src testing results |) {
        my $fdir = File::Spec->catdir($data->{application_dir}, $dir);
        unless (-d $fdir) { make_path($fdir, { mode => 0755 }); }
        croak "Could not locate $fdir" unless (-d $fdir);
        $data->{"${dir}_dir"} = $fdir;
    }

    #my $self = { %Fields, %{$data} };
    return bless $data, $class;
}

sub get_application_dir {
    my $self = shift;
    return $self->{application_dir};
}

sub get_src_dir {
    my $self = shift;
    return $self->{src_dir};
}

sub get_testing_dir {
    my $self = shift;
    return $self->{testing_dir};
}

sub get_results_dir {
    my $self = shift;
    return $self->{results_dir};
}

1;

