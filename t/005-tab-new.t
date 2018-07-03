# -*- perl -*-
# t/005-tab-new.t - check module loading and create testing directory
use 5.14.0;
use warnings;
use Capture::Tiny ( qw| capture_stdout capture_stderr | );
use Carp;
use Cwd;
use File::Path 2.15 (qw| make_path |);
use File::Spec;
use File::Temp ( qw| tempdir |);
use Test::More;
#use Data::Dump ( qw| dd pp | );

BEGIN { use_ok( 'Test::Against::Build' ); }

my $cwd = cwd();
my $self;

##### TESTS OF ERROR CONDITIONS #####

{
    local $@;
    eval { $self = Test::Against::Build->new([]); };
    like($@, qr/Argument to constructor must be hashref/,
        "new: Got expected error message for non-hashref argument");
}

{
    my $tdir1 = tempdir(CLEANUP => 1);
    local $@;
    eval {
        $self = Test::Against::Build->new({
            results_tree => $tdir1,
        });
    };
    like($@, qr/Hash ref must contain 'build_tree' element/,
        "new: Got expected error message; 'build_tree' element absent");
}

{
    my $tdir1 = tempdir(CLEANUP => 1);
    local $@;
    eval {
        $self = Test::Against::Build->new({
            build_tree => $tdir1,
        });
    };
    like($@, qr/Hash ref must contain 'results_tree' element/,
        "new: Got expected error message; 'results_tree' element absent");
}

{
    my $tdir1 = tempdir(CLEANUP => 1);
    local $@;
    my $phony_dir = '/foo';
    eval {
        $self = Test::Against::Build->new({
            build_tree => $tdir1,
            results_tree => $phony_dir,
        });
    };
    like($@, qr/Could not locate directory '$phony_dir' for 'results_tree'/,
        "new: Got expected error message; 'results_tree' not found");
}

{
    my $tdir1 = tempdir(CLEANUP => 1);
    local $@;
    eval {
        $self = Test::Against::Build->new({
            build_tree => $tdir1,
            results_tree => $tdir1,
        });
    };
    like($@, qr/Arguments for 'build_tree' and 'results_tree' must be different directories/,
        "new: Got expected error message; 'build_tree' and 'results_tree' are same directory");
}

##### TESTS OF CORRECTLY BUILT OBJECTS #####

{
    my $tdir1 = tempdir(CLEANUP => 1);
    my $tdir2 = tempdir(CLEANUP => 1);
    setup_test_directories($tdir1, $tdir2);
    $self = Test::Against::Build->new({
        build_tree => $tdir1,
        results_tree => $tdir2,
    });
    ok(defined $self, "new() returned defined object");
    isa_ok($self, 'Test::Against::Build');
    for my $d ('bin', 'lib', '.cpanm', '.cpanreporter') {
        my $expected_dir = File::Spec->catdir($tdir1, $d);
        ok(-d $expected_dir, "new() created '$expected_dir' for '$d' as expected");
    }
    ok(-d $self->get_build_tree, "get_build_tree() returned " . $self->get_build_tree);
    ok(-d $self->get_bindir, "get_bindir() returned " . $self->get_bindir);
    ok(-d $self->get_libdir, "get_libdir() returned " . $self->get_libdir);
    ok(-d $self->get_cpanmdir, "get_cpanmdir() returned " . $self->get_cpanmdir);
    ok(-d $self->get_cpanreporterdir, "get_cpanreporterdir() returned " . $self->get_cpanreporterdir);
    ok(-d $self->get_results_tree, "get_results_tree() returned " . $self->get_results_tree);
    ok(-d $self->get_analysisdir, "get_analysisdir() returned " . $self->get_analysisdir);
    ok(-d $self->get_buildlogsdir, "get_buildlogsdir() returned " . $self->get_buildlogsdir);
    ok(-d $self->get_storagedir, "get_storagedir() returned " . $self->get_storagedir);
    ok(! $self->is_perl_built, "perl executable not yet installed in " . $self->get_bindir);
    ok(! $self->is_cpanm_built, "cpanm executable not yet installed in " . $self->get_bindir);
}

{
    my $tdir1 = tempdir(CLEANUP => 1);
    my $tdir2 = tempdir(CLEANUP => 1);
    setup_test_directories($tdir1, $tdir2);
    my $stdout = capture_stdout {
        $self = Test::Against::Build->new({
            build_tree => $tdir1,
            results_tree => $tdir2,
            verbose => 1,
        });
    };
    ok(defined $self, "new() returned defined object");
    isa_ok($self, 'Test::Against::Build');
    like($stdout,
        qr/Located directory '$tdir1' for 'build_tree'/s,
        "Got expected verbose output"
    );
    like($stdout,
        qr/Located directory '$tdir2' for 'results_tree'/s,
        "Got expected verbose output"
    );
    ok(-d $self->get_build_tree, "get_build_tree() returned " . $self->get_build_tree);
    ok(-d $self->get_bindir, "get_bindir() returned " . $self->get_bindir);
    ok(-d $self->get_libdir, "get_libdir() returned " . $self->get_libdir);
    ok(-d $self->get_cpanmdir, "get_cpanmdir() returned " . $self->get_cpanmdir);
    ok(-d $self->get_cpanreporterdir, "get_cpanreporterdir() returned " . $self->get_cpanreporterdir);
    ok(-d $self->get_results_tree, "get_results_tree() returned " . $self->get_results_tree);
    ok(-d $self->get_analysisdir, "get_analysisdir() returned " . $self->get_analysisdir);
    ok(-d $self->get_buildlogsdir, "get_buildlogsdir() returned " . $self->get_buildlogsdir);
    ok(-d $self->get_storagedir, "get_storagedir() returned " . $self->get_storagedir);
    ok(! $self->is_perl_built, "perl executable not yet installed in " . $self->get_bindir);
    ok(! $self->is_cpanm_built, "cpanm executable not yet installed in " . $self->get_bindir);
}

note("Set PERL_AUTHOR_TESTING_INSTALLED_PERL to run additional tests against installed 'perl' and 'cpanm'")
    unless $ENV{PERL_AUTHOR_TESTING_INSTALLED_PERL};

SKIP: {
    skip 'Test assumes installed perl and cpanm', 18
        unless $ENV{PERL_AUTHOR_TESTING_INSTALLED_PERL};

    my $good_perl = $ENV{PERL_AUTHOR_TESTING_INSTALLED_PERL};
    croak "Could not locate '$good_perl'" unless (-x $good_perl);
    my ($good_path) = $good_perl =~ s{^(.*?)/bin/perl$}{$1}r;
    #say "XXX: $good_perl";
    #say "YYY: $good_path";
    my $tdir2 = tempdir(CLEANUP => 1);
    setup_test_directories_results_only($tdir2);
    $self = Test::Against::Build->new({
        build_tree => $good_path,
        results_tree => $tdir2,
    });
    ok(defined $self, "new() returned defined object");
    isa_ok($self, 'Test::Against::Build');
    for my $d ('bin', 'lib', '.cpanm', '.cpanreporter') {
        my $expected_dir = File::Spec->catdir($good_path, $d);
        ok(-d $expected_dir, "new() created '$expected_dir' for '$d' as expected");
    }
    ok(-d $self->get_build_tree, "get_build_tree() returned " . $self->get_build_tree);
    ok(-d $self->get_bindir, "get_bindir() returned " . $self->get_bindir);
    ok(-d $self->get_libdir, "get_libdir() returned " . $self->get_libdir);
    ok(-d $self->get_cpanmdir, "get_cpanmdir() returned " . $self->get_cpanmdir);
    ok(-d $self->get_cpanreporterdir, "get_cpanreporterdir() returned " . $self->get_cpanreporterdir);
    ok(-d $self->get_results_tree, "get_results_tree() returned " . $self->get_results_tree);
    ok(-d $self->get_analysisdir, "get_analysisdir() returned " . $self->get_analysisdir);
    ok(-d $self->get_buildlogsdir, "get_buildlogsdir() returned " . $self->get_buildlogsdir);
    ok(-d $self->get_storagedir, "get_storagedir() returned " . $self->get_storagedir);
    ok($self->is_perl_built, "perl executable previously installed in " . $self->get_bindir);
    ok($self->is_cpanm_built, "cpanm executable previously installed in " . $self->get_bindir);

    {
        note("Testing via 'module_list'");
        local $@;
        my $list = [
            map { File::Spec->catfile($cwd, 't', 'data', $_) }
            ( qw| Phony-PASS-0.01.tar.gz Phony-FAIL-0.01.tar.gz  | )
        ];
        #pp($list);

        # TODO: Add tests which capture verbose output and match it against
        # expectations.

        #$gzipped_build_log = $self->run_cpanm( {
        my $rv = $self->run_cpanm( {
            module_list => $list,
            title       => 'one-pass-one-fail',
            verbose     => 1,
        } );
        unless ($@) {
            #pass("run_cpanm operated as intended; see $expected_log for PASS/FAIL/etc.");
            pass("run_cpanm operated as intended");
        }
        else {
            fail("run_cpanm did not operate as intended: $@");
        }
        #ok(-f $gzipped_build_log, "Located $gzipped_build_log");
    }
}

#################### TESTING SUBROUTINES ####################

sub setup_test_directories {
    my ($tdir1, $tdir2) = @_;
    my @created = make_path(
        File::Spec->catdir($tdir1, 'bin'),
        File::Spec->catdir($tdir1, 'lib'),
        File::Spec->catdir($tdir1, '.cpanm'),
        File::Spec->catdir($tdir1, '.cpanreporter'),
        File::Spec->catdir($tdir2, 'analysis'),
        File::Spec->catdir($tdir2, 'buildlogs'),
        File::Spec->catdir($tdir2, 'storage'),
        { mode => 0711 }
    );
    return scalar @created;
}

sub setup_test_directories_results_only {
    my ($tdir2) = @_;
    my @created = make_path(
        File::Spec->catdir($tdir2, 'analysis'),
        File::Spec->catdir($tdir2, 'buildlogs'),
        File::Spec->catdir($tdir2, 'storage'),
        { mode => 0711 }
    );
    return scalar @created;
}

#    local $@;
#    my $phony_dir = '/foo';
#    eval { $self = Test::Against::Build->new({ application_dir => $phony_dir }); };
#    like($@, qr/Could not locate $phony_dir/,
#        "new: Got expected error message; 'application_dir' not found");
#}
#
#$self = Test::Against::Build->new( {
#    application_dir         => $tdir,
#} );
#isa_ok ($self, 'Test::Against::Build');
#
#my $top_dir = $self->get_application_dir;
#is($top_dir, $tdir, "Located top-level directory $top_dir");
#
#for my $dir ( qw| testing results | ) {
#    my $fdir = File::Spec->catdir($top_dir, $dir);
#    ok(-d $fdir, "Located $fdir");
#}
#my $testing_dir = $self->get_testing_dir;
#my $results_dir = $self->get_results_dir;
#ok(-d $testing_dir, "Got testing directory: $testing_dir");
#ok(-d $results_dir, "Got results directory: $results_dir");
#
#can_ok('Test::Against::Build', 'configure_build_install_perl');
#can_ok('Test::Against::Build', 'fetch_cpanm');

done_testing();

