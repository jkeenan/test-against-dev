use ExtUtils::MakeMaker;
require 5.10.1;

my $mm_ver = ExtUtils::MakeMaker->VERSION;

WriteMakefile(
    NAME         => 'Test::Against::Blead',
    VERSION_FROM => 'lib/Test/Against/Blead.pm', # finds \$VERSION
    AUTHOR       => 'James E Keenan (jkeenan@cpan.org)',
    ABSTRACT     => 'Functions for testing modules against blead, a branch or a dev release',
    PREREQ_PM    => {
                    'CPAN::cpanminus::reporter::RetainReports' => 0.04,
                    'Data::Dump'                        => 0,
                    'File::Path'                        => 2.15,
                    'File::Spec'                        => 0,
                     'File::Temp'                       => 0,
#                     'App::cpanminus::reporter'         => 0,
#                     'Carp'                             => 0,
#                     'CPAN::Testers::Common::Client'    => 0,
#                     'CPAN::DistnameInfo'               => 0,
#                     'Cwd'                              => 0,
#                     'File::Path'                       => 2.06,
#                     'JSON'                             => 0,
                    'Perl::Download::FTP'               => 0.03,
#                     'URI'                              => 0,
    },
    ( $mm_ver < 6.63_03 ? 'BUILD_REQUIRES' : 'TEST_REQUIRES' ) =>  {
                     'Test::Simple'                     => 0.44,
                     'Capture::Tiny'                    => 0,
                     'Test::RequiresInternet'           => 0,
#                     'Path::Tiny'                       => 0,
    },
);
