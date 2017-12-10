# -*- perl -*-
# t/001-load.t - check module loading and create testing directory
use strict;
use warnings;

use Test::More qw(no_plan); # tests => 2;
use File::Temp ( qw| tempdir |);
use Data::Dump ( qw| dd pp | );
use Capture::Tiny ( qw| capture_stdout | );

BEGIN { use_ok( 'Test::Against::Blead' ); }

my $tdir = tempdir(CLEANUP => 1);
my $self;

$self = Test::Against::Blead->new( {
    application_dir         => $tdir,
} );
isa_ok ($self, 'Test::Against::Blead');
#pp($self);

my $top_dir = $self->get_application_dir;
is($top_dir, $tdir, "Located top-level directory $top_dir");

for my $dir ( qw| src testing results | ) {
    my $fdir = File::Spec->catdir($top_dir, $dir);
    ok(-d $fdir, "Located $fdir");
}
ok(-d $self->get_src_dir, "Got src directory");
ok(-d $self->get_testing_dir, "Got testing directory");
ok(-d $self->get_results_dir, "Got results directory");

my ($rv, $stdout);
$rv = $self->perform_tarball_download( {
    host                => 'ftp.funet.fi',
    hostdir             => '/pub/languages/perl/CPAN/src/5.0',
    release             => 'perl-5.27.1',
    compression         => 'gz',
    verbose             => 0,
    mock                => 1,
} );
ok($rv, 'perform_tarball_download: returned true value when mocking');

$stdout = capture_stdout {
    $rv = $self->perform_tarball_download( {
        host                => 'ftp.funet.fi',
        hostdir             => '/pub/languages/perl/CPAN/src/5.0',
        release             => 'perl-5.27.2',
        compression         => 'xz',
        verbose             => 1,
        mock                => 1,
    } );
};
ok($rv, 'perform_tarball_download: returned true value when mocking and requesting verbose output');
like($stdout, qr/^Mocking/, "Got expected verbose output");

$stdout = capture_stdout {
    $rv = $self->perform_tarball_download( {
        host                => 'ftp.funet.fi',
        hostdir             => '/pub/languages/perl/CPAN/src/5.0',
        release             => 'perl-5.27.2',
        compression         => 'xz',
        verbose             => 1,
    } );
};
ok($rv, 'perform_tarball_download: returned true value');
ok(-f $rv, "Downloaded tarball: $rv");
like($stdout, qr/^Beginning FTP download/s, "Got expected verbose output");
