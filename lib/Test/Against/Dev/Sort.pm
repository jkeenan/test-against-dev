package Test::Against::Dev::Sort;
use strict;
use 5.10.1;
our $VERSION = '0.08';
use Carp;
#use Cwd;
#use File::Basename;
#use File::Fetch;
#use File::Path ( qw| make_path | );
#use File::Spec;
#use File::Temp ( qw| tempdir tempfile | );
#use Archive::Tar;
#use CPAN::cpanminus::reporter::RetainReports;
use Data::Dump ( qw| dd pp | );
#use JSON;
#use Path::Tiny;
#use Perl::Download::FTP;
#use Text::CSV_XS;

=head1 NAME

Test::Against::Dev::Sort - Sort Perl 5 development and RC releases in logical order

=head1 DESCRIPTION

Given a list of strings representing Perl 5 releases in a specific development cycle, ...

    perl-5.27.10
    perl-5.28.0-RC4
    perl-5.27.0
    perl-5.27.9
    perl-5.28.0-RC1
    perl-5.27.11

... sort the list in "logical" order.  By B<logical order> is meant:

=over 4

=item * Development releases:

=over 4

=item * Have an odd minor version number greater than or equal to C<7>.

=item * Have a one- or two-digit patch version number starting at 0.

=back

=item * RC (Release Candidate) releases:

=over 4

=item * Have a minor version number which is even and one greater than the dev version number.

=item * Have a patch version number of C<0> (as we are not concerned with maintenance releases).

=item * Have a string in the format C<-RCxx> following the patch version number, where C<xx> is a one- or two-digit number starting with C<1>.

=back

=back

For the example above, the desired result would be:

    perl-5.27.0
    perl-5.27.9
    perl-5.27.10
    perl-5.27.11
    perl-5.28.0-RC1
    perl-5.28.0-RC4

=cut

sub new {
    my ($class, $minor_dev) = @_;
    croak "Minor version must be odd" unless $minor_dev % 2;
    croak "Minor version must be >= 7" unless $minor_dev >= 7;

    my $data = {};
    return bless $data, $class;
}

1;
