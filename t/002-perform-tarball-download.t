# -*- perl -*-
# t/001-load.t - check module loading and create testing directory
use strict;
use warnings;

use Test::More;
use File::Temp ( qw| tempdir |);
use Data::Dump ( qw| dd pp | );
use Capture::Tiny ( qw| capture_stdout capture_stderr | );
use Test::RequiresInternet ('ftp.funet.fi' => 21);
BEGIN { use_ok( 'Test::Against::Blead' ); }

my $tdir = tempdir(CLEANUP => 1);
my $self;

$self = Test::Against::Blead->new( {
    application_dir         => $tdir,
} );
isa_ok ($self, 'Test::Against::Blead');

my $host = 'ftp.funet.fi';
my $hostdir = '/pub/languages/perl/CPAN/src/5.0';

{
    local $@;
    eval {
        my $rv = $self->perform_tarball_download( [
            host                => $host,
            hostdir             => $hostdir,
            release             => 'perl-5.27.1',
            compression         => 'gz',
            verbose             => 0,
            mock                => 1,
      ] );
    };
    like($@, qr/perform_tarball_download: Must supply hash ref as argument/,
        "perform_tarball_download: Got expected error message for lack of hashref as argument");
}

{
    local $@;
    my $bad_key = 'foo';
    eval {
        my $rv = $self->perform_tarball_download( {
            host                => $host,
            hostdir             => $hostdir,
            release             => 'perl-5.27.1',
            compression         => 'gz',
            verbose             => 0,
            mock                => 1,
            $bad_key            => 'bar',
      } );
    };
    like($@, qr/perform_tarball_download: '$bad_key' is not a valid element/,
        "perform_tarball_download: Got expected error message for invalid element");
}

{
    local $@;
    my $bad_release = '5.27.1';
    eval {
        my $rv = $self->perform_tarball_download( {
            host                => $host,
            hostdir             => $hostdir,
            release             => $bad_release,
            compression         => 'gz',
            verbose             => 0,
            mock                => 1,
      } );
    };
    like($@, qr/perform_tarball_download: '$bad_release' does not conform to pattern/,
        "perform_tarball_download: Got expected error message for invalid release");
}
{
    local $@;
    my $bad_compression = 'foo';
    eval {
        my $rv = $self->perform_tarball_download( {
            host                => $host,
            hostdir             => $hostdir,
            release             => 'perl-5.27.1',
            compression         => $bad_compression,
            verbose             => 0,
            mock                => 1,
      } );
    };
    like($@, qr/perform_tarball_download: '$bad_compression' is not a valid compression format/,
        "perform_tarball_download: Got expected error message for invalid compression format");
}

SKIP: {
    skip "Set PERL_ALLOW_NETWORK_TESTING to conduct live tests", 17
        unless $ENV{PERL_ALLOW_NETWORK_TESTING};
    my ($rv, $stdout, $release_dir, $configure_command, $alt, $make_install_command);

    {
        local $@;
        eval { $release_dir = $self->get_release_dir(); };
        like($@, qr/release directory has not yet been defined; run perform_tarball_download\(\)/,
            "get_release_dir: Got expected error message for premature call");
    };
    $rv = $self->perform_tarball_download( {
        host                => $host,
        hostdir             => $hostdir,
        release             => 'perl-5.27.1',
        compression         => 'gz',
        verbose             => 0,
        mock                => 1,
    } );
    ok($rv, 'perform_tarball_download: returned true value when mocking');
    $release_dir = $self->get_release_dir();
    ok(-d $release_dir, "Located release dir: $release_dir");
    $configure_command = $self->access_configure_command();
    is($configure_command,
       "sh ./Configure -des -Dusedevel -Uversiononly -Dprefix=$self->get_release_dir -Dman1dir=none -Dman3dir=none",
        "Got default configure command"
    );
    $alt = "sh ./Configure -des -Dusedevel -Dprefix=$self->get_release_dir -Uversiononly -Dman1dir=none -Dman3dir=none";
    $configure_command = $self->access_configure_command($alt);
    is($configure_command, $alt, "Got user-specified configure command");

    $make_install_command = $self->access_make_install_command();
    is($make_install_command, 'make install', "Got default make install command");
    $alt = 'make -j4 install';
    $make_install_command = $self->access_make_install_command($alt);
    is($make_install_command, $alt, "Got user specified make install command");

    $stdout = capture_stdout {
        $rv = $self->perform_tarball_download( {
            host                => $host,
            hostdir             => $hostdir,
            release             => 'perl-5.27.2',
            compression         => 'xz',
            verbose             => 1,
            mock                => 1,
        } );
    };
    ok($rv, 'perform_tarball_download: returned true value when mocking and requesting verbose output');
    like($stdout, qr/Mocking/, "Got expected verbose output");
    $release_dir = $self->get_release_dir();
    ok(-d $release_dir, "Located release dir: $release_dir");

    SKIP: {
        skip 'Live FTP download', 7 unless $ENV{PERL_AUTHOR_TESTING};
        note("Performing live FTP download of Perl tarball;\n  this may take a while.");
        $stdout = capture_stdout {
            $rv = $self->perform_tarball_download( {
                host                => $host,
                hostdir             => $hostdir,
                release             => 'perl-5.27.2',
                compression         => 'xz',
                verbose             => 1,
                mock                => 0,
            } );
        };
        ok($rv, 'perform_tarball_download: returned true value');
        $release_dir = $self->get_release_dir();
        ok(-d $release_dir, "Located release dir: $release_dir");
        ok(-f $rv, "Downloaded tarball: $rv");
        like($stdout, qr/^Beginning FTP download/s, "Got expected verbose output");

        $rv = $self->perform_tarball_download( {
            host                => $host,
            hostdir             => $hostdir,
            release             => 'perl-5.27.3',
            compression         => 'xz',
        } );
        ok($rv, 'perform_tarball_download: returned true value');
        $release_dir = $self->get_release_dir();
        ok(-d $release_dir, "Located release dir: $release_dir");
        ok(-f $rv, "Downloaded tarball: $rv");
    }
}

done_testing();
