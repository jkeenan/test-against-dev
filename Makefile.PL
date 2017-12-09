

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Test::Against::Blead',
    VERSION_FROM => 'lib/Test/Against/Blead.pm', # finds \$VERSION
    AUTHOR       => 'James E Keenan (jkeenan@cpan.org)',
    ABSTRACT     => 'Functions for testing modules against blead, a branch or a dev release',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                    },
);
