# -*- perl -*-
# t/008-salvage.t - when you've already got a perl and a cpanm and have
# installed a set of CPAN modules with cpanm
use strict;
use warnings;
use feature 'say';

use Test::More;
use Carp;
use Cwd;
use File::Copy;
use File::Spec;
use File::Path ( qw| make_path | );
use File::Temp ( qw| tempdir tempfile |);
use Data::Dump ( qw| dd pp | );
use Test::Against::Dev::Salvage;

my $self;
my $perl_version = 'perl-5.27.4';
my $title = 'salvage-cpan-river';

my $cwd = cwd();
my $tdir = tempdir(CLEANUP => 1);
my ($fh, $tfile) = tempfile();

{
    note("Tests of error conditions:  defects in call syntax");
    {
        local $@;
        eval {
            $self = Test::Against::Dev::Salvage->new( [
                path_to_cpanm_build_log => $tfile,
                perl_version            => $perl_version,
                title                   => $title,
                results_dir             => $tdir,
            ] );
        };
        like($@, qr/Must supply hash ref as argument/,
                "Test::Against::Dev::Salvage->new(): Got expected error message: absence of hash ref");
    }

    {
        local $@;
        eval {
            $self = Test::Against::Dev::Salvage->new( {
                path_to_cpanm_build_log => $tfile,
                perl_version            => $perl_version,
                title                   => $title,
            } );
        };
        like($@, qr/Need 'results_dir' element in arguments hash ref/,
                "Test::Against::Dev::Salvage->new(): Got expected error message: no value supplied for 'results_dir'");
    }

    {
        local $@;
        eval {
            $self = Test::Against::Dev::Salvage->new( {
                path_to_cpanm_build_log => $tfile,
                perl_version            => $perl_version,
                results_dir             => $tdir,
            } );
        };
        like($@, qr/Need 'title' element in arguments hash ref/,
                "Test::Against::Dev::Salvage->new(): Got expected error message: no value supplied for 'title'");
    }

    {
        local $@;
        eval {
            $self = Test::Against::Dev::Salvage->new( {
                path_to_cpanm_build_log => $tfile,
                title                   => $title,
                results_dir             => $tdir,
            } );
        };
        like($@, qr/Need 'perl_version' element in arguments hash ref/,
                "Test::Against::Dev::Salvage->new(): Got expected error message: no value supplied for 'perl_version'");
    }

    {
        local $@;
        eval {
            $self = Test::Against::Dev::Salvage->new( {
                perl_version            => $perl_version,
                title                   => $title,
                results_dir             => $tdir,
            } );
        };
        like($@, qr/Need 'path_to_cpanm_build_log' element in arguments hash ref/,
                "Test::Against::Dev::Salvage->new(): Got expected error message: no value supplied for 'path_to_cpanm_build_log'");
    }

    {
        local $@;
        my $bad_build_log = '/foo/bar/baz/1234567890';
        eval {
            $self = Test::Against::Dev::Salvage->new( {
                path_to_cpanm_build_log => $bad_build_log,
                perl_version            => $perl_version,
                title                   => $title,
                results_dir             => $tdir,
            } );
        };
        like($@, qr/Could not locate cpanm build.log at '$bad_build_log'/,
            "Test::Against::Dev::Salvage->new(): Got expected error message: bad value for 'path_to_cpanm_build_log'");
    }

    {
        local $@;
        eval {
            $self = Test::Against::Dev::Salvage->new( {
                path_to_cpanm_build_log => $tfile,
                perl_version            => $perl_version,
                title                   => undef,
                results_dir             => $tdir,
            } );
        };
        like($@, qr/Must supply value for 'title' element/,
                "Test::Against::Dev::Salvage->new(): Got expected error message: undefined value for 'title'");
    }

    {
        local $@;
        eval {
            $self = Test::Against::Dev::Salvage->new( {
                path_to_cpanm_build_log => $tfile,
                perl_version            => $perl_version,
                title                   => '',
                results_dir             => $tdir,
            } );
        };
        like($@, qr/Must supply value for 'title' element/,
                "Test::Against::Dev::Salvage->new(): Got expected error message: empty value for 'title'");
    }

    {
        local $@;
        my $bad_perl_version = '5.27.3';
        eval {
            $self = Test::Against::Dev::Salvage->new( {
                path_to_cpanm_build_log => $tfile,
                perl_version            => $bad_perl_version,
                title                   => $title,
                results_dir             => $tdir,
            } );
        };
        like($@, qr/'$bad_perl_version' does not conform to pattern/,
                "Test::Against::Dev::Salvage->new(): Got expected error message: invalid perl_version");
    }

}

{
    my $application_dir = tempdir(CLEANUP => 1);
    my $perl_version = 'perl-5.29.0';
    my $timestamped_workdir = File::Spec->catdir(
        $application_dir, 'testing', $perl_version, '.cpanm', 'work', '12345.123'
    );
    my @created = make_path($timestamped_workdir, { mode => 0711 })
        or croak "Unable to create $timestamped_workdir for testing";
    my $build_log = File::Spec->catfile($timestamped_workdir, 'build.log');
    my $dummy_log = File::Spec->catfile($cwd, 't', 'data', 'sample.build.log');
    ok(-f $dummy_log, "Able to locate $dummy_log for testing");
    copy $dummy_log => $build_log
        or croak "Unable to copy $dummy_log to $build_log";
    ok(-f $build_log, "Able to locate $build_log for testing");

    my $results_dir = File::Spec->catdir( $application_dir, 'results' );
    my $vresults_dir = File::Spec->catdir( $results_dir, $perl_version );
    my $analysis_dir = File::Spec->catdir( $vresults_dir, 'analysis' );
    my $buildlogs_dir = File::Spec->catdir( $vresults_dir, 'buildlogs' );
    my $storage_dir = File::Spec->catdir( $vresults_dir, 'storage' );
    @created = make_path(
        $analysis_dir,
        $buildlogs_dir,
        $storage_dir,
        {mode => 0711}
    ) or croak "Unable to create results directories";
    for my $d ( $analysis_dir, $buildlogs_dir, $storage_dir ) {
        ok(-d $d, "Created $d for testing");
    }
    $self = Test::Against::Dev::Salvage->new( {
        path_to_cpanm_build_log => $build_log,
        perl_version            => $perl_version,
        title                   => $title,
        results_dir             => $results_dir,
        verbose                 => 1,
    } );
    ok(defined $self, "Test::Against::Dev::Salvage->new() returned defined value");
    isa_ok($self, 'Test::Against::Dev::Salvage');
    dd($self);

    note("Test inheritance");
    isa_ok($self, 'Test::Against::Dev');
    can_ok('Test::Against::Dev::Salvage', ( qw|
        gzip_cpanm_build_log
        analyze_cpanm_build_logs
        analyze_json_logs
        get_cpanm_dir
    | ) );

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

