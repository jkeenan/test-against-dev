use ExtUtils::MakeMaker;
require 5.10.1;

my $mm_ver = ExtUtils::MakeMaker->VERSION;

WriteMakefile(
    NAME         => 'Test::Against::Blead',
    VERSION_FROM => 'lib/Test/Against/Blead.pm',
    AUTHOR       => 'James E Keenan (jkeenan@cpan.org)',
    ABSTRACT     => 'Functions for testing modules against blead, a branch or a dev release',
    PREREQ_PM    => {
                    'Carp'                              => 0,
                    'CPAN::cpanminus::reporter::RetainReports' => 0.04,
                    'Data::Dump'                        => 0,
                    'File::Path'                        => 2.15,
                    'File::Spec'                        => 0,
                    'File::Temp'                       => 0,
                    'Perl::Download::FTP'               => 0.03,
    },
    ( $mm_ver < 6.63_03 ? 'BUILD_REQUIRES' : 'TEST_REQUIRES' ) =>  {
                     'Test::Simple'                     => 0.44,
                     'Capture::Tiny'                    => 0,
                     'Test::RequiresInternet'           => 0,
    },
);
