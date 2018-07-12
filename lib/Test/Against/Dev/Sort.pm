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


... sort the list in "logical" order.  By B<logical order> is meant:

=over 4

=item * Development releases:

=over 4

=item * Have an odd minor version number.

=item * Have a one- or two-digit patch version number starting at 0.

=back

=item * RC (Release Candidate) releases:

=over 4

=item * Have a minor version number which is even and one greater than the dev version number.

=item * Have a patch version number of C<0> (as we are not concerned with maintenance releases).

=item * Have a string in the format C<-RCxx> following the patch version number, where C<xx> is a one- or two-digit number starting with C<1>.

=back

=back

=cut

sub new {

}

1;
