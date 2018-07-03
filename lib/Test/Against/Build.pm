package Test::Against::Build;
use strict;
use 5.10.1;
our $VERSION = '0.08';
use Carp;
use Cwd;
use File::Basename;
use File::Fetch;
use File::Path ( qw| make_path | );
use File::Spec;
use File::Temp ( qw| tempdir tempfile | );
use Archive::Tar;
use CPAN::cpanminus::reporter::RetainReports;
use Data::Dump ( qw| dd pp | );
use JSON;
use Path::Tiny;
use Perl::Download::FTP;
use Text::CSV_XS;

=head1 NAME

Test::Against::Build - Test CPAN modules against specific Perl build

=head1 SYNOPSIS

    my $self = Test::Against::Build->new( {
        build_tree      => '/path/to/top/of/build_tree',
        results_tree    => '/path/to/top/of/results_tree',
        verbose => 1,
    } );

    my $gzipped_build_log = $self->run_cpanm( {
        module_file => '/path/to/cpan-river-file.txt',
        title       => 'cpan-river-1000',
        verbose     => 1,
    } );

    $ranalysis_dir = $self->analyze_cpanm_build_logs( { verbose => 1 } );

    $fcdvfile = $self->analyze_json_logs( { verbose => 1, sep_char => '|' } );

    834:sub setup_results_directories {
    933:sub run_cpanm {
    1010:sub gzip_cpanm_build_log {

=head1 DESCRIPTION

=head2 Who Should Use This Library?

This library should be used by anyone who wishes to assess the impact of a
given build of the Perl 5 core distribution on the installability of libraries
found on the Comprehensive Perl Archive Network (CPAN).

=head2 The Problem to Be Addressed

=head3 The Perl Annual Development Cycle

Perl 5 undergoes an annual development cycle whose components typically include:

=over 4

=item * Individual commits to the Perl 5 F<git> repository

These commits may be identified by commit IDs (SHAs), branches or tags.

=item * Release tarballs

=over 4

=item * Monthly development release tarballs

Whose version numbers follow the convention of C<5.27.0>, C<5.27.1>,
etc., where the middle digits are always odd numbers.

=item * Release Candidate (RC) tarballs

Whose version numbers follow the convention of C<5.28.0-RC1>, C<5.28.0-RC2>,
C<5.28.1-RC1>.

=item * Production release tarballs

Whose version numbers follow the convention of C<5.28.0> (new release);
C<5.28.1>, C<5.28.2>, etc. (maintenance releases).

=back

=back

=head3 Measuring the Impact of Changes in Core on CPAN Modules

You can configure, build and install a F<perl> executable starting from any of
the above components and you can install CPAN modules against any such F<perl>
executable.  Given a list of specific CPAN modules, you may want to be able to
compare the results you get from trying to install that list against different
F<perl> executables built from different commits or releases at various points
in the development cycle.  To make such comparisons, you will need to have
data generated and recorded in a consistent format.  This library provides
methods for that data generation and recording.

=head2 High-Level View of What the Module Does

=head3 Tree Structure

For any particular attempt to build a F<perl> executable from any of the
starting points described above, F<Test::Against::Build> guarantees that there
exists on disk B<two> directory trees:

=over 4

=item 1 The build tree

The build tree is a directory beneath which F<perl>, other executables and
libraries will be installed (or already are installed).  As such, the
structure of this tree will look like this:

    top_of_build_tree/bin/
                      bin/perl
                      bin/perldoc
                      bin/cpan
                      bin/cpanm
    ...
    top_of_build_tree/lib/
                      lib/perl5/
                      lib/perl5/5.29.0/
                      lib/perl5/site_perl/
    ...
    top_of_build_tree/.cpanm/
    top_of_build_tree/.cpanreporter/

F<Test::Against::Build> presumes that you will be using Miyagawa's F<cpanm>
utility to install modules from CPAN.  The F<.cpanm> and F<.cpanreporter>
directories will be the locations where data concerning attempts to install CPAN
modules are recorded.

=item 2 The results tree

The results tree is a directory beneath which data parsed from the F<.cpanm>
directory is formatted and stored.  Its format looks like this:

    top_of_results_tree/analysis/
                        buildlogs/
                        storage/

=back

The names of the top-level directories are arbitrary; the names of their
subdirectories are not.  The top-level directories may be located anywhere
writable on disk and need not share a common parent directory.  It is the
F<Test::Against::Build> object which will establish a relationship between the
two trees.

=head3 Installation of F<perl> and F<cpanm>

F<Test::Against::Build> does B<not> provide you with methods to build or
install these executables.  It presumes that you know how to build F<perl>
from source, whether that be from a specific F<git> checkout or from a release
tarball.  It further presumes that you know how to install F<cpanm> against
that F<perl>.  It does provide a method to identify the directory you should
use as the value of the C<-Dprefix=> option to F<Configure>.  It also provides
methods to determine that you have installed F<perl> and F<cpanm> in the
expected locations.  Once that determination has been made, it provides you
with methods to run F<cpanm> against a specific list of modules, parse the
results into files in JSON format and then summarize those results in a
delimiter-separated-values file (such as a pipe-separated-values (C<.psv>)
file).

Why, you may ask, does F<Test::Against::Build> B<not> provide methods to
install these executables?  There are a number of reasons why not.

=over 4

=item * F<perl> and F<cpanm> already installed

You may already have on disk one or more F<perl>s built from specific commits
or release tarballs and have no need to re-install them.

=item * Starting from F<git> commit versus starting from a tarball

You can build F<perl> either way, but there's no need to have code in this
package to express both ways.

=item * Many ways to configure F<perl>

F<perl> configuration is a matter of taste.  The only thing which this package
needs to provide you is a value for the C<-Dprefix=> option.  It should go
without saying that if want to measure the impact on CPAN modules of two
different builds of F<perl>, you should call F<Configure> with exactly the
same set of options for each.

=back

The examples below will provide guidance.

=head1 METHODS

=head2 C<new()>

=over 4

=item * Purpose

Test::Against::Build constructor.  Guarantees that the build tree and results
tree have the expected directory structure.  Determines whether F<perl> and
F<cpanm> have already been installed or not.

=item * Arguments

    my $self = Test::Against::Build->new( {
        build_tree      => '/path/to/top/of/build_tree',
        results_tree    => '/path/to/top/of/results_tree',
        verbose => 1,
    } );

=item * Return Value

Test::Against::Build object.

=item * Comment

=back

=cut

sub new {
    my ($class, $args) = @_;

    croak "Argument to constructor must be hashref"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';
    for my $d (qw| build_tree results_tree |) {
        croak "Hash ref must contain '$d' element"
            unless $args->{$d};
        unless (-d $args->{$d}) {
            croak "Could not locate directory '$args->{$d}' for '$d'";
        }
        else {
            say "Located directory '$args->{$d}' for '$d'" if $verbose;
        }
    }
    # Crude test of difference of directories;
    # need to take into account, e.g., symlinks, relative paths
    croak "Arguments for 'build_tree' and 'results_tree' must be different directories"
        unless $args->{build_tree} ne $args->{results_tree};

    my $data;
    for my $k (keys %{$args}) {
        $data->{$k} = $args->{$k};
    }

    for my $subdir ( 'bin', 'lib' ) {
        my $dir = File::Spec->catdir($data->{build_tree}, $subdir);
        my $key = "${subdir}dir";
        $data->{$key} = (-d $dir) ? $dir : undef;
    }
    for my $subdir ( '.cpanm', '.cpanreporter' ) {
        my $dir = File::Spec->catdir($data->{build_tree}, $subdir);
        my $key = "${subdir}dir";
        $key =~ s{^\.(.*)}{$1};
        $data->{$key} = (-d $dir) ? $dir : undef;
    }
    for my $subdir ( qw| analysis buildlogs storage | ) {
        my $dir = File::Spec->catdir($data->{results_tree}, $subdir);
        unless (-d $dir) {
            my @created = make_path($dir, { mode => 0711 })
                or croak "Unable to make_path '$dir'";
        }
        my $key = "${subdir}dir";
        $data->{$key} = $dir;
    }

    return bless $data, $class;
}

=head2 Accessors

The following accessors return the absolute path to the directories in their names:

=over 4

=item * C<get_build_tree()>

=item * C<get_bindir()>

=item * C<get_libdir()>

=item * C<get_cpanmdir()>

=item * C<get_cpanreporterdir()>

=item * C<get_results_dir()>

=item * C<get_analysisdir()>

=item * C<get_buildlogsdir()>

=item * C<get_storagedir()>

=back

=cut

sub get_build_tree { my $self = shift; return $self->{build_tree}; }
sub get_bindir { my $self = shift; return $self->{bindir}; }
sub get_libdir { my $self = shift; return $self->{libdir}; }
sub get_cpanmdir { my $self = shift; return $self->{cpanmdir}; }
sub get_cpanreporterdir { my $self = shift; return $self->{cpanreporterdir}; }
sub get_results_tree { my $self = shift; return $self->{results_tree}; }
sub get_analysisdir { my $self = shift; return $self->{analysisdir}; }
sub get_buildlogsdir { my $self = shift; return $self->{buildlogsdir}; }
sub get_storagedir { my $self = shift; return $self->{storagedir}; }


=head2 C<run_cpanm()>

=over 4

=item * Purpose

=item * Arguments

=item * Return Value

=item * Comment

=back

=cut


=head2 C<analyze_cpanm_build_logs()>

=over 4

=item * Purpose

=item * Arguments

=item * Return Value

=item * Comment

=back

=cut


=head2 C<analyze_json_logs()>

=over 4

=item * Purpose

=item * Arguments

=item * Return Value

=item * Comment

=back

=cut


=head2 C<new()>

=over 4

=item * Purpose

=item * Arguments

=item * Return Value

=item * Comment

=back

=cut


=pod

    my $gzipped_build_log = $self->run_cpanm( {
        module_file => '/path/to/cpan-river-file.txt',
        title       => 'cpan-river-1000',
        verbose     => 1,
    } );

    $ranalysis_dir = $self->analyze_cpanm_build_logs( { verbose => 1 } );

    $fcdvfile = $self->analyze_json_logs( { verbose => 1, sep_char => '|' } );

    834:sub setup_results_directories {
    933:sub run_cpanm {
    1010:sub gzip_cpanm_build_log {

=cut



1;

__END__


