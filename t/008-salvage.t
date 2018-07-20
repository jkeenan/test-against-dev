# -*- perl -*-
# t/008-salvage.t - when you've already got a perl and a cpanm and have
# installed a set of CPAN modules with cpanm
use strict;
use warnings;
use feature 'say';

use Test::More;
use Carp;
use Cwd;
use File::Basename;
use File::Spec::Functions ( qw| catdir catfile | );
use File::Path ( qw| make_path | );
use File::Temp ( qw| tempdir tempfile |);
use Data::Dump ( qw| dd pp | );
use Test::RequiresInternet ('ftp.funet.fi' => 21);
use Test::Against::Dev;

my $self;
my $perl_version = 'perl-5.27.4';
my $title = 'salvage-cpan-river';

my $cwd = cwd();
my $tdir = tempdir(CLEANUP => 1);

{
    note("Tests of error conditions:  defects in call syntax");
    {
        local $@;
        eval {
            $self = Test::Against::Dev->new_with_existing_cpanm_run( [
                path_to_perl    => $tdir,
                application_dir => $tdir,
                perl_version    => $perl_version,
            ] );
        };
        like($@, qr/new_with_existing_cpanm_run: Must supply hash ref as argument/,
                "new_with_existing_cpanm_run(): Got expected error message: absence of hash ref");
    }

    {
        local $@;
        eval {
            $self = Test::Against::Dev->new_with_existing_cpanm_run( {
                path_to_perl    => $tdir,
                perl_version    => $perl_version,
                title           => $title,
            } );
        };
        like($@, qr/Need 'application_dir' element in arguments hash ref/,
                "new_with_existing_cpanm_run(): Got expected error message: no value supplied for 'application_dir'");
    }

    {
        local $@;
        eval {
            $self = Test::Against::Dev->new_with_existing_cpanm_run( {
                path_to_perl    => $tdir,
                application_dir => $tdir,
                title           => $title,
            } );
        };
        like($@, qr/Need 'perl_version' element in arguments hash ref/,
                "new_with_existing_cpanm_run(): Got expected error message: no value supplied for 'perl_version'");
    }

    {
        local $@;
        eval {
            $self = Test::Against::Dev->new_with_existing_cpanm_run( {
                path => $tdir,
                application_dir => $tdir,
                perl_version    => $perl_version,
                title           => $title,
            } );
        };
        like($@, qr/Need 'path_to_perl' element in arguments hash ref/,
            "new_with_existing_cpanm_run(): Got expected error message: lack 'path_to_perl' element in hash ref");
    }

    {
        local $@;
        eval {
            $self = Test::Against::Dev->new_with_existing_cpanm_run( {
                path_to_perl    => $tdir,
                application_dir => $tdir,
                perl_version    => $perl_version,
                #title           => $title,
            } );
        };
        like($@, qr/Need 'title' element in arguments hash ref/,
                "new_with_existing_cpanm_run(): Got expected error message: no value supplied for 'title'");
    }

}

####################

note("Set PERL_AUTHOR_TESTING_INSTALLED_PERL to run additional tests against installed 'perl' and 'cpanm'")
    unless $ENV{PERL_AUTHOR_TESTING_INSTALLED_PERL};

# Must set above envvar to a complete path ending in /bin/perl.

SKIP: {
    skip 'Test assumes installed perl and cpanm', 10
        unless $ENV{PERL_AUTHOR_TESTING_INSTALLED_PERL};

    my $good_path = $ENV{PERL_AUTHOR_TESTING_INSTALLED_PERL};
    croak "Could not locate '$good_path'" unless (-x $good_path);

    {
        local $@;
        my $bad_perl_version = '5.27.3';
        eval {
            $self = Test::Against::Dev->new_with_existing_cpanm_run( {
                path_to_perl    => $good_path,
                application_dir => $tdir,
                perl_version    => $bad_perl_version,
                title           => $title,
            } );
        };
        like($@, qr/'$bad_perl_version' does not conform to pattern/,
            "Got expected error message: '$bad_perl_version' does not conform to pattern");
    }

    my ($application_dir, $perl_version) = $good_path =~ m{^(.*?)/testing/([^/]*?)/bin/perl$};
    {
        local $@;
        my $bad_application_dir = catdir('foo', 'bar');
        eval {
            $self = Test::Against::Dev->new_with_existing_cpanm_run( {
                path_to_perl    => $good_path,
                application_dir => $bad_application_dir,
                perl_version    => $perl_version,
                title           => $title,
            } );
        };
        like($@, qr/Could not locate $bad_application_dir/,
            "Got expected error message: Could not locate path '$bad_application_dir'");
    }

    # First test expected to PASS with real values

    $self = Test::Against::Dev->new_with_existing_cpanm_run( {
        path_to_perl    => $good_path,
        application_dir => $application_dir,
        perl_version    => $perl_version,
        title           => $title,
    } );
    ok(defined $self, "new_with_existing_cpanm_run() returned defined value");
    isa_ok($self, 'Test::Against::Dev');

    my ($expected_release_dir) = $good_path =~ s{^(.*)/bin/perl}{$1}r;
    my $release_dir = $self->get_release_dir();
    my $bin_dir = $self->get_bin_dir();
    my $lib_dir = $self->get_lib_dir();
    my $cpanm_dir = $self->get_cpanm_dir();
    is($release_dir, $expected_release_dir, "Got expected release_dir '$release_dir'");
    is($bin_dir, catdir($release_dir, 'bin'), "Got expected bin_dir '$bin_dir'");
    is($lib_dir, catdir($release_dir, 'lib'), "Got expected lib_dir '$lib_dir'");
    is($cpanm_dir, catdir($release_dir, '.cpanm'), "Got expected cpanm_dir '$cpanm_dir'");
    is($self->{this_perl}, catfile($bin_dir, 'perl'), "Got expected 'perl'");
    my $this_perl = $self->get_this_perl();
    is($this_perl, $good_path, "Got expected 'perl': $this_perl");
    my $this_cpanm = $self->get_this_cpanm();
    is($this_cpanm, catfile($bin_dir, 'cpanm'), "Got expected 'cpanm': $this_cpanm");

    pp({ %{$self} });

    my $build_log_link = catfile($self->get_release_dir(), '.cpanm', 'build.log');
    croak "Could not find build.log symlink at $build_log_link" unless (-l $build_log_link);
    #say "XXX: $build_log_link";
    my $real_log = readlink($build_log_link);
    #say "YYY: $real_log";
    croak "Could not locate target of build.log symlink" unless (-f $real_log);

    my $gzipped_build_log = $self->gzip_cpanm_build_log();
    ok(-f $gzipped_build_log, "Located $gzipped_build_log");

    my $ranalysis_dir;
    {
        local $@;
        eval { $ranalysis_dir = $self->analyze_cpanm_build_logs( [ verbose => 1 ] ); };
        like($@, qr/analyze_cpanm_build_logs: Must supply hash ref as argument/,
            "analyze_cpanm_build_logs(): Got expected error message for lack of hash ref");
    }

    $ranalysis_dir = $self->analyze_cpanm_build_logs( { verbose => 1 } );
    ok(-d $ranalysis_dir,
        "analyze_cpanm_build_logs() returned path to version-specific analysis directory '$ranalysis_dir'");

    my $rv;
    {
        local $@;
        eval { $rv = $self->analyze_json_logs( verbose => 1 ); };
        like($@, qr/analyze_json_logs: Must supply hash ref as argument/,
            "analyze_json_logs(): Got expected error message: absence of hash ref");
    }

    {
        local $@;
        eval { $rv = $self->analyze_json_logs( { verbose => 1, sep_char => "\t" } ); };
        like($@, qr/analyze_json_logs: Currently only pipe \('\|'\) and comma \(','\) are supported as delimiter characters/,
            "analyze_json_logs(): Got expected error message: unsupported delimiter");
    }

    my $fpsvfile = $self->analyze_json_logs( { verbose => 1 } );
    ok($fpsvfile, "analyze_json_logs() returned true value");
    ok(-f $fpsvfile, "Located '$fpsvfile'");

    my $fcsvfile = $self->analyze_json_logs( { verbose => 1 , sep_char => ',' } );
    ok($fcsvfile, "analyze_json_logs() returned true value");
    ok(-f $fcsvfile, "Located '$fcsvfile'");
}

# Try to ensure that we get back to where we started so that tempdirs can be
# cleaned up
chdir $cwd;

done_testing();

