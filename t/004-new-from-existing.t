# -*- perl -*-
# t/004-new-from-existing.t - when you've already got a perl and a cpanm
use strict;
use warnings;
use feature 'say';

use Test::More;
use Carp;
use File::Basename;
use File::Spec::Functions ( qw| catdir catfile | );
use File::Path ( qw| make_path | );
use File::Temp ( qw| tempdir |);
use Data::Dump ( qw| dd pp | );
use Test::RequiresInternet ('ftp.funet.fi' => 21);
use Test::Against::Dev;

my $self;
my $perl_version = 'perl-5.27.4';

my $tdir = tempdir(CLEANUP => 1);
#my $tdir = '/home/jkeenan/tmp/bbc/results';
ok(create_sample_files($tdir), "Sample files created for testing in $tdir");

{
    local $@;
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( [
            path_to_perl    => $tdir,
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
            path_to_perl    => $tdir,
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
            path_to_perl    => $tdir,
            results_dir     => $tdir,
        } );
    };
    like($@, qr/Need 'perl_version' element in arguments hash ref/,
            "Got expected error message: no value supplied for 'perl_version'");
}

{
    local $@;
    eval {
        $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
            path => $tdir,
            results_dir     => $tdir,
            perl_version    => $perl_version,
        } );
    };
    like($@, qr/Need 'path_to_perl' element in arguments hash ref/,
        "Got expected error message: lack 'path_to_perl' element in hash ref");
}

####################

{
    local $@;
    my $path_to_perl = catfile($tdir, 'foo', 'bar');
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
    my $path_to_perl = catfile($tdir, 'foo', 'perl');
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
    my $path_to_perl = catfile($tdir, 'baz', 'perl');
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
    my $d = catfile($tdir, 'bom');
    my $e = catdir($d, 'lib');
    my $path_to_perl = catfile($d, 'bin', 'perl');
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
    my $d = catfile($tdir, 'boo');
    my $e = catdir($d, 'lib');
    my $path_to_perl = catfile($d, 'bin', 'perl');
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
    my $d = catfile($tdir, 'boq');
    my $e = catdir($d, 'lib');
    my $path_to_perl = catfile($d, 'bin', 'perl');
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
    my $d = catfile($tdir, 'bos');
    my $e = catdir($d, 'lib');
    my $bin_dir = catfile($d, 'bin');
    my $path_to_perl = catfile($bin_dir, 'perl');
    my $path_to_cpanm = catfile($bin_dir, 'cpanm');
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

####################

note("Set PERL_AUTHOR_TESTING_INSTALLED_PERL to run additional tests against installed 'perl' and 'cpanm'")
    unless $ENV{PERL_AUTHOR_TESTING_INSTALLED_PERL};

SKIP: {
    skip 'Test assumes installed perl and cpanm', 8
        unless $ENV{PERL_AUTHOR_TESTING_INSTALLED_PERL};

    my $good_path = $ENV{PERL_AUTHOR_TESTING_INSTALLED_PERL};
    croak "Could not locate '$good_path'" unless (-x $good_path);
    my ($perl_version) = $good_path =~ s{^.*/([^/]*?)/bin/perl$}{$1}r;
    $self = Test::Against::Dev->new_from_existing_perl_cpanm( {
        path_to_perl    => $good_path,
        results_dir     => $tdir,
        perl_version    => $perl_version,
    } );
    ok(defined $self, "new_from_existing_perl_cpanm() returned defined value");
    isa_ok($self, 'Test::Against::Dev');

    my ($expected_release_dir) = $good_path =~ s{^(.*)/bin/perl}{$1}r;
    my $release_dir = $self->get_release_dir();
    my $bin_dir = $self->get_bin_dir();
    my $lib_dir = $self->get_lib_dir();
    is($release_dir, $expected_release_dir, "Got expected release_dir '$release_dir'");
    is($bin_dir, catdir($release_dir, 'bin'), "Got expected bin_dir '$bin_dir'");
    is($lib_dir, catdir($release_dir, 'lib'), "Got expected lib_dir '$lib_dir'");
    is($self->{this_perl}, catfile($bin_dir, 'perl'), "Got expected 'perl'");
    my $this_perl = $self->get_this_perl();
    is($this_perl, $good_path, "Got expected 'perl': $this_perl");
    my $this_cpanm = $self->get_this_cpanm();
    is($this_cpanm, catfile($bin_dir, 'cpanm'), "Got expected 'cpanm': $this_cpanm");

    pp({ %{$self} });
    note("Status");

    my $expected_log = catfile($self->get_release_dir(), '.cpanm', 'build.log');
    note("Expecting to log cpanm in $expected_log");
    {
        local $@;
        my $mod = 'Module::Build';
        my $list = [ $mod ];
        eval {
            $self->run_cpanm( { module_list => $list, verbose => 1 } );
        };
        like($@, qr/Must supply value for 'title' element/,
            "Got expected failure message for lack of 'title' element");
    }

    {
        local $@;
        my $mod = 'Module::Build';
        my $list = [ $mod ];
        $self->run_cpanm( {
            module_list => $list,
            title       => 'just-one-module',
            verbose     => 1,
        } );
        if ($@) { fail("run_cpanm failed to install $mod"); }
        else { pass("run_cpanm installed $mod (or reported that it was already installed)"); }
    }

    {
        local $@;
        my $file = catfile('t', 'data', 'two-modules.txt');
        ok(-f $file, "Located $file for testing");
        $self->run_cpanm( {
            module_file => $file,
            title       => 'two-modules-one-likely-to-fail',
            verbose     => 1,
        } );
        unless ($@) {
            pass("run_cpanm operated as intended; see $expected_log for PASS/FAIL/etc.");
        }
        else {
            fail("run_cpanm did not operate as intended");
        }

    }

}

done_testing();

########## SUBROUTINES ##########

sub create_sample_files {
    my $tdir = shift;
    my ($parent_dir, @created, $f, $g);
    my ($bin_dir, $lib_dir);

    # Create foo/bar only
    $parent_dir = catdir($tdir, 'foo');
    @created = make_path($parent_dir, { mode => 0755 });
    $f = create_file($parent_dir, 'bar');

    # Create foo/perl but don't make it executable
    $f = create_file($parent_dir, 'perl');

    # Create an executable perl but not in a directory named bin/
    $parent_dir = catdir($tdir, 'baz');
    @created = make_path($parent_dir, { mode => 0755 });
    $f = create_file($parent_dir, 'perl', 0755);

    # Create executable perl in bin/ but don't create a lib/ directory
    $bin_dir = catdir($tdir, 'bom', 'bin');
    @created = make_path($bin_dir, { mode => 0755 });
    $f = create_file($bin_dir, 'perl', 0755);

    # Create executable perl in bin/; create lib/ but don't make it writable
    $bin_dir = catdir($tdir, 'boo', 'bin');
    @created = make_path($bin_dir, { mode => 0755 });
    $f = create_file($bin_dir, 'perl', 0755);
    $lib_dir = catdir($tdir, 'boo', 'lib');
    @created = make_path($lib_dir, { mode => 0555 });

    # Create executable perl in bin/, writable lib/, but then make top-level
    # unwriteable
    $parent_dir = catdir($tdir, 'boq');
    $bin_dir = catdir($parent_dir, 'bin');
    $lib_dir = catdir($parent_dir, 'lib');
    @created = make_path($parent_dir, $bin_dir, $lib_dir, { mode => 0755 });
    $f = create_file($bin_dir, 'perl', 0755);
    chmod 0555, $parent_dir;

    # Create executable perl in bin/, writable lib/, create cpanm in bin but
    # don't make it executable
    $parent_dir = catdir($tdir, 'bos');
    $bin_dir = catdir($parent_dir, 'bin');
    $lib_dir = catdir($parent_dir, 'lib');
    @created = make_path($parent_dir, $bin_dir, $lib_dir, { mode => 0755 });
    $f = create_file($bin_dir, 'perl', 0755);
    $g = create_file($bin_dir, 'cpanm', 0644);

    return 1;
}

sub create_file {
    my ($directory, $filename, $mode) = @_;
    my $f = catfile($directory, $filename);
    open my $OUT, '>', $f or croak "Unable to open $f for writing";
    close $OUT or croak "Unable to close $f after writing";
    $mode ||= 0644;
    chmod $mode, $f;
    return $f;
}
