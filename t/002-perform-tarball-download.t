# -*- perl -*-
# t/001-load.t - check module loading and create testing directory
use strict;
use warnings;

use Test::More tests => 8;
use File::Temp ( qw| tempdir |);
use Data::Dump ( qw| dd pp | );
use Capture::Tiny ( qw| capture_stdout | );
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

SKIP: {
    skip "Set PERL_ALLOW_NETWORK_TESTING to conduct live tests", 5
        unless $ENV{PERL_ALLOW_NETWORK_TESTING};
    my ($rv, $stdout);
    $rv = $self->perform_tarball_download( {
        host                => $host,
        hostdir             => $hostdir,
        release             => 'perl-5.27.1',
        compression         => 'gz',
        verbose             => 0,
        mock                => 1,
    } );
    ok($rv, 'perform_tarball_download: returned true value when mocking');

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
    like($stdout, qr/^Mocking/, "Got expected verbose output");

    SKIP: {
        skip 'Live FTP download', 3 unless $ENV{PERL_AUTHOR_TESTING};
        note("Performing live FTP download of Perl tarball;\n  this may take a while.");
        $stdout = capture_stdout {
            $rv = $self->perform_tarball_download( {
                host                => $host,
                hostdir             => $hostdir,
                release             => 'perl-5.27.2',
                compression         => 'xz',
                verbose             => 1,
            } );
        };
        ok($rv, 'perform_tarball_download: returned true value');
        ok(-f $rv, "Downloaded tarball: $rv");
        like($stdout, qr/^Beginning FTP download/s, "Got expected verbose output");
    }
}
