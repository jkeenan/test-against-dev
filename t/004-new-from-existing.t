# -*- perl -*-
# t/004-new-from-existing.t - when you've already got a perl and a cpanm
use strict;
use warnings;
use feature 'say';

use Test::More;
plan skip_all => 'Testing not feasible except by author'
    unless $ENV{PERL_AUTHOR_TESTING};
use Carp;
use File::Basename;
use File::Temp ( qw| tempdir |);
use Data::Dump ( qw| dd pp | );
#use Capture::Tiny ( qw| capture_stdout capture_stderr | );
#use Test::RequiresInternet ('ftp.funet.fi' => 21);

BEGIN { use_ok( 'Test::Against::Dev' ); }

my $self;
my $good_path = '/home/jkeenan/tmp/bbc/testing/perl-5.27.6/bin/perl';
my $tdir = tempdir(CLEANUP => 1);
my $perl_version = 'perl-5.27.6';

{
    local $@;
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( [
            path_to_perl    => $good_path,
            results_dir     => $tdir,
            perl_version    => $perl_version,
        ] );
    };
    like($@, qr/new_from_existing_perl_cpanm: Must supply hash ref as argument/,
            "Got expected error message: absence of hashref");
}

{
    local $@;
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
            path_to_perl    => $good_path,
            perl_version    => $perl_version,
        } );
    };
    like($@, qr/Need 'results_dir' element in arguments hash ref/,
            "Got expected error message: no value supplied for 'results_dir'");
}

{
    local $@;
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
            path_to_perl    => $good_path,
            results_dir     => $tdir,
        } );
    };
    like($@, qr/Need 'perl_version' element in arguments hash ref/,
            "Got expected error message: no value supplied for 'perl_version'");
}

{
    local $@;
    my $path_to_perl = '/home/jkeenan/tmp/foo/bar';
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
            path_to_perl    => $path_to_perl,
            results_dir     => $tdir,
            perl_version    => $perl_version,
        } );
    };
    like($@, qr/Could not locate perl executable at '$path_to_perl'/,
        "Got expected error message: value for 'path_to_perl' not named perl");
}

{
    local $@;
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
            path => $good_path,
            results_dir     => $tdir,
            perl_version    => $perl_version,
        } );
    };
    like($@, qr/Need 'path_to_perl' element in arguments hash ref/,
        "Got expected error message: lack 'path_to_perl' element in hash ref");
}

{
    local $@;
    my $path_to_perl = '/home/jkeenan/tmp/foo/perl';
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
            path_to_perl    => $path_to_perl,
            results_dir     => $tdir,
            perl_version    => $perl_version,
        } );
    };
    like($@, qr/Could not locate perl executable at '$path_to_perl'/,
        "Got expected error message: '$path_to_perl' is not executable");
}

{
    local $@;
    my $path_to_perl = '/home/jkeenan/tmp/baz/perl';
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
            path_to_perl    => $path_to_perl,
            results_dir     => $tdir,
            perl_version    => $perl_version,
        } );
    };
    like($@, qr<'$path_to_perl' not found in directory named 'bin/'>,
        "Got expected error message: '$path_to_perl' not in directory 'bin/'");
}

{
    local $@;
    my $d = '/home/jkeenan/tmp/bom';
    my $e = File::Spec->catdir($d, 'lib');
    my $path_to_perl = File::Spec->catfile($d, 'bin', 'perl');
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
            path_to_perl    => $path_to_perl,
            results_dir     => $tdir,
            perl_version    => $perl_version,
        } );
    };
    like($@, qr/Could not locate '$e'/,
        "Got expected error message: Could not locate appropriate 'lib/' directory");
}

{
    local $@;
    my $d = '/home/jkeenan/tmp/bop';
    my $e = File::Spec->catdir($d, 'lib');
    my $path_to_perl = File::Spec->catfile($d, 'bin', 'perl');
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
            path_to_perl    => $path_to_perl,
            results_dir     => $tdir,
            perl_version    => $perl_version,
        } );
    };
    like($@, qr/'$e' not writable/,
        "Got expected error message: '$e' not writable");
}

{
    local $@;
    my $d = '/home/jkeenan/tmp/boq';
    my $e = File::Spec->catdir($d, 'lib');
    my $path_to_perl = File::Spec->catfile($d, 'bin', 'perl');
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
            path_to_perl    => $path_to_perl,
            results_dir     => $tdir,
            perl_version    => $perl_version,
        } );
    };
    like($@, qr/'$d' not writable/,
        "Got expected error message: '$d' not writable");
}

{
    local $@;
    my $d = '/home/jkeenan/tmp/bos';
    my $e = File::Spec->catdir($d, 'lib');
    my $bin_dir = File::Spec->catfile($d, 'bin');
    my $path_to_perl = File::Spec->catfile($bin_dir, 'perl');
    my $path_to_cpanm = File::Spec->catfile($bin_dir, 'cpanm');
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
            path_to_perl    => $path_to_perl,
            results_dir     => $tdir,
            perl_version    => $perl_version,
        } );
    };
    like($@, qr/Could not locate cpanm executable at '$path_to_cpanm'/,
        "Got expected error message: Could not locate an executable 'cpanm' at '$path_to_cpanm'");
}

{
    $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
        path_to_perl    => $good_path,
        results_dir     => $tdir,
        perl_version    => $perl_version,
    } );
    ok(defined $self, "new_from_existing_perl_cpanm() returned defined value");
    isa_ok($self, 'Test::Against::Dev');
    pp({%$self});
    pass($0);
}

done_testing();
