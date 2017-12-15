package Test::Against::Dev;
use strict;
use 5.10.1;
our $VERSION = '0.01';
use Carp;
use Cwd;
use File::Basename;
use File::Fetch;
use File::Path ( qw| make_path | );
use File::Spec;
use File::Temp ( qw| tempdir tempfile | );
use Archive::Tar;
use Data::Dump ( qw| dd pp | );
use CPAN::cpanminus::reporter::RetainReports;
use JSON;
use Path::Tiny;
use Perl::Download::FTP;
use Text::CSV_XS;

=head1 NAME

Test::Against::Dev - Test CPAN modules against Perl dev releases

=head1 SYNOPSIS

TK

=head1 DESCRIPTION

=head2 Who Should Use This Library?

This library should be used by anyone who wishes to assess the impact of
month-to-month changes in the Perl 5 core distribution on the installability of
libraries found on the Comprehensive Perl Archive Network (CPAN).

=head2 The Problem to Be Addressed

This problem is typically referred to as B<Blead Breaks CPAN> (or B<BBC> for
short).  Perl 5 undergoes an annual development cycle characterized by monthly
releases whose version numbers follow the convention of C<5.27.0>, C<5.27.1>,
etc., where the middle digits are always odd numbers.  (Annual production
releases and subsequent maintenance releases have even-numbered middle digits,
I<e.g.>, C<5.26.0>, C<5.26.1>, etc.)  A monthly development release is
essentially a roll-up of a month's worth of commits to the master branch known
as B<blead> (pronounced I<"bleed">).  Changes in the Perl 5 code base have the
potential to adversely impact the installability of existing CPAN libraries.
Hence, various individuals have, over the years, developed ways of testing
those libraries against blead and reporting problems to those people actively
involved in the ongoing development of the Perl 5 core distribution -- people
typically referred to as the Perl 5 Porters.

This library is intended as a contribution to those efforts.  It is intended
to provide a monthly snapshot of the impact of Perl 5 core development on
important CPAN libraries.

=head2 The Approach Test-Against-Dev Currently Takes and How It May Change in the Future

Unlike other efforts, F<Test-Against-Dev> does not depend on test reports
sent to L<CPANtesters.org|http://www.cpantesters.org/>.  Hence, it should be
unaffected by any technical problems which that site may face.  As a
consequence, however, a user of this library must be willing to maintain more
of her own local infrastructure than a typical CPANtester would maintain.

While this library could, in principle, be used to test the entirety of CPAN,
it is probably better suited for testing selected subsets of CPAN libraries
which the user deems important to her individual or organizational needs.

This library is currently focused on monthly development releases of Perl 5.
It does not directly provide a basis for identifying individual commits to
blead which adversely impacted particular CPAN libraries.  It "tests against
dev" more than it "tests against blead" -- hence, the name of the library.
However, once it has gotten some production experience, it may be extended to,
say, measure the effect of individual commits to blead on CPAN libraries using
the previous monthly development release as a baseline.

This library is currently focused on Perl 5 libraries publicly available on
CPAN.  In the future, it may be extended to be able to include an
organization's private libraries as well.

This library is currently focused on blead, the master branch of the Perl 5
core distribution.  However, it could, in principle, be extended to assess the
impact on CPAN libraries of code in non-blead ("smoke-me") branches as well.

=head2 What Is the Result Produced by This Library?

Currently, if you run code built with this library on a monthly basis, you
will produce an updated version of a pipe-separated-values (PSV) plain-text
file suitable for opening in a spreadsheet.  The columns in that PSV file will
be these:

    dist
    perl-5.27.0.author
    perl-5.27.0.distname
    perl-5.27.0.distversion
    perl-5.27.0.grade
    perl-5.27.1.author
    perl-5.27.1.distname
    perl-5.27.1.distversion
    perl-5.27.1.grade
    ...

So the output for particular CPAN libraries will look like this:

    dist|perl-5.27.0.author|perl-5.27.0.distname|perl-5.27.0.distversion|perl-5.27.0.grade|perl-5.27.1.author|perl-5.27.1.distname|perl-5.27.1.distversion|perl-5.27.1.grade|...
    Acme-CPANAuthors|ISHIGAKI|Acme-CPANAuthors-0.26|0.26|PASS|ISHIGAKI|Acme-CPANAuthors-0.26|0.26|PASS|...
    Algorithm-C3|HAARG|Algorithm-C3-0.10|0.10|PASS|HAARG|Algorithm-C3-0.10|0.10|PASS|...

If a particular CPAN library receives a grade of C<PASS> one month and a grade
of <FAIL> month, it ought to be inspected for the cause of that breakage.
Sometimes the change in Perl 5 is wrong and needs to be reverted.  Sometimes
the change in Perl 5 is correct (or, at least, plausible) but exposes
sub-optimal code in the CPAN module.  Sometimes the failure is due to external
conditions, such as a change in a C library on the testing platform.  There's
no way to write code to figure out which situation -- or mix of situations --
we are in.  The human user must intervene at this point.

=head2 What Preparations Are Needed to Use This Library?

=over 4

=item * Platform

The user should select a machine/platform which is likely to be reasonably stable over one Perl 5 annual development cycle.  We understand that the platform's system administrator will be updating system libraries for security and other reasons over time.  But it would be a hassle to run this software on a machine scheduled for a complete major version update of its operating system.

=item * Perl 5 Configuration

The user must decide on a Perl 5 configuration before using
F<Test-Against-Dev> on a regular basis and not change that over the course of
the testing period.  Otherwise, the results may reflect changes in that
configuration rather than changes in Perl 5 core distribution code or changes
in the targeted CPAN libraries.

"Perl 5 configuration" means the way one calls F<Configure> when building Perl
5 from source, <e.g.>:

    sh ./Configure -des -Dusedevel \
        -Duseithreads \
        -Doptimize="-O2 -pipe -fstack-protector -fno-strict-aliasing"

So, you should not configure without threads one month but with threads
another month.  You should not switch to debugging builds half-way through the
testing period.

=item * Selection of CPAN Libraries for Testing

TK

=back

=head2 Different Ways of Using This Library

TK

=head1 METHODS

=head2 C<new()>

=over 4

=item * Purpose

=item * Arguments

=item * Return Value

=item * Comment

=back

=cut

# What args must be passed to constructor?
# application top-level directory
# Constructor will get path to top-level directory for application,
# compose names of other directories in the tree, verify they exist or create
# them as needed.

sub new {
    my ($class, $args) = @_;

    croak "Argument to constructor must be hashref"
        unless ref($args) eq 'HASH';
    croak "Hash ref must contain 'application_dir' element"
        unless $args->{application_dir};
    croak "Could not locate $args->{application_dir}"
        unless (-d $args->{application_dir});

    my $data;
    for my $k (keys %{$args}) {
        $data->{$k} = $args->{$k};
    }

    for my $dir (qw| testing results |) {
        my $fdir = File::Spec->catdir($data->{application_dir}, $dir);
        unless (-d $fdir) { make_path($fdir, { mode => 0755 }); }
        croak "Could not locate $fdir" unless (-d $fdir);
        $data->{"${dir}_dir"} = $fdir;
    }

    $data->{perl_version_pattern} = qr/^perl-5\.\d+\.\d{1,2}$/;
    return bless $data, $class;
}

sub get_application_dir {
    my $self = shift;
    return $self->{application_dir};
}

sub get_testing_dir {
    my $self = shift;
    return $self->{testing_dir};
}

sub get_results_dir {
    my $self = shift;
    return $self->{results_dir};
}

sub perform_tarball_download {
    my ($self, $args) = @_;
    croak "perform_tarball_download: Must supply hash ref as argument"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';
    my $mock = delete $args->{mock} || '';
    my %eligible_args = map { $_ => 1 } ( qw|
        host hostdir perl_version compression work_dir
    | );
    for my $k (keys %$args) {
        croak "perform_tarball_download: '$k' is not a valid element"
            unless $eligible_args{$k};
    }
    croak "perform_tarball_download: '$args->{perl_version}' does not conform to pattern"
        unless $args->{perl_version} =~ m/$self->{perl_version_pattern}/;

    my %eligible_compressions = map { $_ => 1 } ( qw| gz bz2 xz | );
    croak "perform_tarball_download: '$args->{compression}' is not a valid compression format"
        unless $eligible_compressions{$args->{compression}};

    croak "Could not locate '$args->{work_dir}' for purpose of downloading tarball and building perl"
        if (exists $args->{work_dir} and (! -d $args->{work_dir}));

    $self->{$_} = $args->{$_} for keys %$args;

    $self->{tarball} = "$self->{perl_version}.tar.$self->{compression}";

    my $this_release_dir = File::Spec->catdir($self->get_testing_dir(), $self->{perl_version});
    unless (-d $this_release_dir) { make_path($this_release_dir, { mode => 0755 }); }
    croak "Could not locate $this_release_dir" unless (-d $this_release_dir);
    $self->{release_dir} = $this_release_dir;

    my $ftpobj = Perl::Download::FTP->new( {
        host        => $self->{host},
        dir         => $self->{hostdir},
        Passive     => 1,
        verbose     => $verbose,
    } );

    unless ($mock) {
        if (! $self->{work_dir}) {
            $self->{restore_to_dir} = cwd();
            $self->{work_dir} = tempdir(CLEANUP => 1);
        }
        if ($verbose) {
            say "Beginning FTP download (this will take a few minutes)";
            say "Perl configure-build-install cycle will be performed in $self->{work_dir}";
        }
        my $tarball_path = $ftpobj->get_specific_release( {
            release         => $self->{tarball},
            path            => $self->{work_dir},
        } );
        unless (-f $tarball_path) {
            croak "Tarball $tarball_path not found: $!";
        }
        else {
            say "Path to tarball is $tarball_path" if $verbose;
            $self->{tarball_path} = $tarball_path;
            return ($tarball_path, $self->{work_dir});
        }
    }
    else {
        say "Mocking; not really attempting FTP download" if $verbose;
        return 1;
    }
}

sub get_release_dir {
    my $self = shift;
    if (! defined $self->{release_dir}) {
        croak "release directory has not yet been defined; run perform_tarball_download()";
    }
    else {
        return $self->{release_dir};
    }
}

sub access_configure_command {
    my ($self, $arg) = @_;
    my $cmd;
    if (length $arg) {
        $cmd = $arg;
    }
    else {
        $cmd = "sh ./Configure -des -Dusedevel -Uversiononly -Dprefix=";
        $cmd .= $self->get_release_dir;
        $cmd .= " -Dman1dir=none -Dman3dir=none";
    }
    $self->{configure_command} = $cmd;
}

sub access_make_install_command {
    my ($self, $arg) = @_;
    my $cmd;
    if (length $arg) {
        $cmd = $arg;
    }
    else {
        $cmd = "make install"
    }
    $self->{make_install_command} = $cmd;
}

sub configure_build_install_perl {
    my ($self, $args) = @_;
    my $cwd = cwd();
    $args //= {};
    croak "perform_tarball_download: Must supply hash ref as argument"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';

    # What I want in terms of verbose output:
    # 0: No verbose output from Test::Against::Dev
    #    Minimal output from tar, Configure, make
    #    (tar xzf; Configure, make 1>/dev/null
    # 1: Verbose output from Test::Against::Dev
    #    Minimal output from tar, Configure, make
    #    (tar xzf; Configure, make 1>/dev/null
    # 2: Verbose output from Test::Against::Dev
    #    Verbose output from tar ('v')
    #    Regular output from Configure, make

    # Use default configure and make install commands unless an argument has
    # been passed.
    my $acc = $self->access_configure_command($args->{configure_command} || '');
    my $mic = $self->access_make_install_command($args->{make_install_command} || '');
    unless ($verbose > 1) {
        $self->access_configure_command($acc . " 1>/dev/null");
        $self->access_make_install_command($mic . " 1>/dev/null");
    }

    chdir $self->{work_dir} or croak "Unable to change to $self->{work_dir}";
    my $untar_command = ($verbose > 1) ? 'tar xzvf' : 'tar xzf';
    system(qq|$untar_command $self->{tarball_path}|)
        and croak "Unable to untar $self->{tarball_path}";
    say "Tarball has been untarred into ", File::Spec->catdir($self->{work_dir}, $self->{perl_version})
        if $verbose;
    my $build_dir = $self->{perl_version};
    chdir $build_dir or croak "Unable to change to $build_dir";
    say "Configuring perl with '$self->{configure_command}'" if $verbose;
    system(qq|$self->{configure_command}|)
        and croak "Unable to configure with '$self->{configure_command}'";
    say "Building and installing perl with '$self->{make_install_command}'" if $verbose;
    system(qq|$self->{make_install_command}|)
        and croak "Unable to build and install with '$self->{make_install_command}'";
    my $rdir = $self->get_release_dir();
    my $bin_dir = File::Spec->catdir($rdir, 'bin');
    my $lib_dir = File::Spec->catdir($rdir, 'lib');
    my $this_perl = File::Spec->catfile($bin_dir, 'perl');
    croak "Could not locate '$bin_dir'" unless (-d $bin_dir);
    croak "Could not locate '$lib_dir'" unless (-d $lib_dir);
    croak "Could not locate '$this_perl'" unless (-f $this_perl);
    $self->{bin_dir} = $bin_dir;
    $self->{lib_dir} = $lib_dir;
    $self->{this_perl} = $this_perl;
    chdir $cwd or croak "Unable to change back to $cwd";
    if ($self->{restore_to_dir}) {
        chdir $self->{restore_to_dir} or croak "Unable to change back to $self->{restore_to_dir}";
    }
    return $this_perl;
}

sub get_this_perl {
    my $self = shift;
    if (! defined $self->{this_perl}) {
        croak "perl has not yet been installed; run configure_build_install_perl";
    }
    else {
        return $self->{this_perl};
    }
}

sub get_bin_dir {
    my $self = shift;
    if (! defined $self->{bin_dir}) {
        croak "bin directory has not yet been defined; run configure_build_install_perl()";
    }
    else {
        return $self->{bin_dir};
    }
}

sub get_lib_dir {
    my $self = shift;
    if (! defined $self->{lib_dir}) {
        croak "lib directory has not yet been defined; run configure_build_install_perl()";
    }
    else {
        return $self->{lib_dir};
    }
}

sub fetch_cpanm {
    my ($self, $args) = @_;
    $args //= {};
    croak "perform_tarball_download: Must supply hash ref as argument"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';
    my $uri = (exists $args->{uri} and length $args->{uri})
        ? $args->{uri}
        : 'http://cpansearch.perl.org/src/MIYAGAWA/App-cpanminus-1.7043/bin/cpanm';

    my $cpanm_dir = File::Spec->catdir($self->get_release_dir(), '.cpanm');
    unless (-d $cpanm_dir) { make_path($cpanm_dir, { mode => 0755 }); }
    croak "Could not locate $cpanm_dir" unless (-d $cpanm_dir);
    $self->{cpanm_dir} = $cpanm_dir;

    say "Fetching 'cpanm' from $uri" if $verbose;
    my $ff = File::Fetch->new(uri => $uri);
    my ($scalar, $where);
    $where = $ff->fetch( to => \$scalar );
    croak "Did not download 'cpanm'" unless (-f $where);
    open my $IN, '<', \$scalar or croak "Unable to open scalar for reading";
    my $this_cpanm = File::Spec->catfile($self->{bin_dir}, 'cpanm');
    open my $OUT, '>', $this_cpanm or croak "Unable to open $this_cpanm for writing";
    while (<$IN>) {
        chomp $_;
        say $OUT $_;
    }
    close $OUT or croak "Unalbe to close $this_cpanm after writing";
    close $IN or croak "Unable to close scalar after reading";
    unless (-f $this_cpanm) {
        croak "Unable to locate '$this_cpanm'";
    }
    else {
        say "Installed '$this_cpanm'" if $verbose;
    }
    my $cnt = chmod 0755, $this_cpanm;
    croak "Unable to make '$this_cpanm' executable" unless $cnt;
    $self->{this_cpanm} = $this_cpanm;
}

sub get_this_cpanm {
    my $self = shift;
    if (! defined $self->{this_cpanm}) {
        croak "cpanm has not yet been installed against the 'perl' being tested; run fetch_cpanm()";
    }
    else {
        return $self->{this_cpanm};
    }
}

sub get_cpanm_dir {
    my $self = shift;
    if (! defined $self->{cpanm_dir}) {
        croak "cpanm directory has not yet been defined; run fetch_cpanm()";
    }
    else {
        return $self->{cpanm_dir};
    }
}

sub setup_results_directories {
    my $self = shift;
    croak "Perl release not yet defined" unless $self->{perl_version};
    my $vresults_dir = File::Spec->catdir($self->get_results_dir, $self->{perl_version});
    my $buildlogs_dir = File::Spec->catdir($vresults_dir, 'buildlogs');
    my $analysis_dir = File::Spec->catdir($vresults_dir, 'analysis');
    my $storage_dir = File::Spec->catdir($vresults_dir, 'storage');
    my @created = make_path( $vresults_dir, $buildlogs_dir, $analysis_dir, $storage_dir,
        { mode => 0755 });
    for my $dir (@created) { croak "$dir not found" unless -d $dir; }
    $self->{vresults_dir} = $vresults_dir;
    $self->{buildlogs_dir} = $buildlogs_dir;
    $self->{analysis_dir} = $analysis_dir;
    $self->{storage_dir} = $storage_dir;
    return scalar(@created);
}

sub run_cpanm {
    my ($self, $args) = @_;
    $args //= {};
    croak "run_cpanm: Must supply hash ref as argument"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';
    my %eligible_args = map { $_ => 1 } ( qw|
        module_file module_list title
    | );
    for my $k (keys %$args) {
        croak "run_cpanm: '$k' is not a valid element"
            unless $eligible_args{$k};
    }
    if (exists $args->{module_file} and exists $args->{module_list}) {
        croak "run_cpanm: Supply either a file for 'module_file' or an array ref for 'module_list' but not both";
    }
    if ($args->{module_file}) {
        croak "run_cpanm: Could not locate '$args->{module_file}'"
            unless (-f $args->{module_file});
    }
    if ($args->{module_list}) {
        croak "run_cpanm: Must supply array ref for 'module_list'"
            unless ref($args->{module_list}) eq 'ARRAY';
    }

    unless (defined $args->{title} and length $args->{title}) {
        croak "Must supply value for 'title' element";
    }
    $self->{title} = $args->{title};

    unless (-d $self->{vresults_dir}) {
        $self->setup_results_directories();
    }

    my $cpanreporter_dir = File::Spec->catdir($self->get_release_dir(), '.cpanreporter');
    unless (-d $cpanreporter_dir) { make_path($cpanreporter_dir, { mode => 0755 }); }
    croak "Could not locate $cpanreporter_dir" unless (-d $cpanreporter_dir);
    $self->{cpanreporter_dir} = $cpanreporter_dir;

    unless ($self->{cpanm_dir}) {
        say "Defining previously undefined cpanm_dir" if $verbose;
        my $cpanm_dir = File::Spec->catdir($self->get_release_dir(), '.cpanm');
        unless (-d $cpanm_dir) { make_path($cpanm_dir, { mode => 0755 }); }
        croak "Could not locate $cpanm_dir" unless (-d $cpanm_dir);
        $self->{cpanm_dir} = $cpanm_dir;
    }

    say "cpanm_dir: ", $self->get_cpanm_dir() if $verbose;
    local $ENV{PERL_CPANM_HOME} = $self->get_cpanm_dir();

    my @modules = ();
    if ($args->{module_list}) {
        @modules = @{$args->{module_list}};
    }
    elsif ($args->{module_file}) {
        @modules = path($args->{module_file})->lines({ chomp => 1 });
    }
    my @cmd = (
        $self->get_this_perl,
        "-I$self->get_lib_dir",
        $self->get_this_cpanm,
        @modules,
    );
    eval {
        local $@;
        my $rv = system(@cmd);
        say "<$@>" if $@;
        if ($verbose) {
            say $self->get_this_cpanm(), " exited with ", $rv >> 8;
        }
    };
    my $gzipped_build_log = $self->gzip_cpanm_build_log();
    say "See gzipped build.log in $gzipped_build_log" if $verbose;

    return $gzipped_build_log;
}

sub gzip_cpanm_build_log {
    my ($self) = @_;
    my $build_log_link = File::Spec->catfile($self->get_cpanm_dir, 'build.log');
    croak "Did not find symlink for build.log at $build_log_link"
        unless (-l $build_log_link);
    my $real_log = readlink($build_log_link);
    # Read the directory holding gzipped build.logs.  If there are no files
    # whose names match the pattern, then set $run to 01.  If there are,
    # determine the next appropriate run number.
    my $pattern = qr/^$self->{title}\.$self->{perl_version}\.(\d{2})\.build\.log\.gz$/;
    $self->{gzlog_pattern} = $pattern;
    opendir my $DIRH, $self->{buildlogs_dir} or croak "Unable to open buildlogs_dir for reading";
    my @files_found = grep { -f $_ and $_ =~ m/$pattern/ } readdir $DIRH;
    closedir $DIRH or croak "Unable to close buildlogs_dir after reading";
    my $srun = (! @files_found) ? sprintf("%02d" => 1) : sprintf("%02d" => (scalar(@files_found) + 1));
    my $gzipped_build_log = join('.' => (
        $self->{title},
        $self->{perl_version},
        $srun,
        'build',
        'log',
        'gz'
    ) );
    my $gzlog = File::Spec->catfile($self->{buildlogs_dir}, $gzipped_build_log);
    system(qq| gzip -c $real_log > $gzlog |)
        and croak "Unable to gzip $real_log to $gzlog";
    $self->{gzlog} = $gzlog;
}

sub new_from_existing_perl_cpanm {
    my ($class, $args) = @_;
    $args //= {};
    croak "new_from_existing_perl_cpanm: Must supply hash ref as argument"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';
    for my $el ( qw| path_to_perl results_dir perl_version | ) {
        croak "Need '$el' element in arguments hash ref"
            unless exists $args->{$el};
    }
    croak "Could not locate perl executable at '$args->{path_to_perl}'"
        unless (-x $args->{path_to_perl} and basename($args->{path_to_perl}) =~ m/^perl/);

    my $this_perl = $args->{path_to_perl};

    # TODO: Check $args->{perl_version} against pattern.
    # TODO: Create $args->{results_dir} if it doesn't already exist.
    # TODO: Add a dryrun parameter?
    #
    # Is the perl's parent directory bin/?
    # Is there a lib/ directory next to parent bin/?
    # Can the user write to directory lib/?
    # What is the parent of bin/ and lib/?
    # Is that parent writable (as user will need to create .cpanm/ and
    # .cpanreporter/ there)?
    # Is there a 'cpanm' executable located in bin?

    my ($volume,$directories,$file) = File::Spec->splitpath($this_perl);
    my @directories = File::Spec->splitdir($directories);
    pop @directories if $directories[-1] eq '';
    croak "'$this_perl' not found in directory named 'bin/'"
        unless $directories[-1] eq 'bin';
    my $bin_dir = File::Spec->catdir(@directories);

    my $lib_dir = File::Spec->catdir(@directories[0 .. ($#directories - 1)], 'lib');
    croak "Could not locate '$lib_dir'" unless (-d $lib_dir);
    croak "'$lib_dir' not writable" unless (-w $lib_dir);

    my $release_dir  = File::Spec->catdir(@directories[0 .. ($#directories - 1)]);
    croak "'$release_dir' not writable" unless (-w $release_dir);

    my $this_cpanm = File::Spec->catfile($bin_dir, 'cpanm');
    croak "Could not locate cpanm executable at '$this_cpanm'"
        unless (-x $this_cpanm);

    my $data = {
        perl_version    => $args->{perl_version},
        results_dir     => $args->{results_dir},
        release_dir     => $release_dir,
        bin_dir         => $bin_dir,
        lib_dir         => $lib_dir,
        this_perl       => $this_perl,
        this_cpanm      => $this_cpanm,
    };

    return bless $data, $class;
}

sub analyze_cpanm_build_logs {
    my ($self, $args) = shift;
    $args //= {};
    croak "perform_tarball_download: Must supply hash ref as argument"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';
    my $dryrun  = delete $args->{dryrun} || '';

    my $gzlog = $self->{gzlog};
    my ($srun) = basename($gzlog) =~ m/$self->{gzlog_pattern}/;
    croak "Unable to identify run number within $gzlog filename"
        unless $srun;
    my $ranalysis_dir = File::Spec->catdir($self->{analysis_dir}, $srun);
    unless (-d $ranalysis_dir) { make_path($ranalysis_dir, { mode => 0755 }); }
        croak "Could not locate $ranalysis_dir" unless (-d $ranalysis_dir);

    my ($fh, $working_log) = tempfile();
    system(qq|gunzip -c $gzlog > $working_log|)
        and croak "Unable to gunzip $gzlog to $working_log";

    my $reporter = CPAN::cpanminus::reporter::RetainReports->new(
      force => 1, # ignore mtime check on build.log
      build_logfile => $working_log,
      build_dir => $self->get_cpanm_dir,
      'ignore-versions' => 1,
    );
    croak "Unable to create new reporter for $working_log"
        unless defined $reporter;
    if ($dryrun) {
        say "Ready to process $working_log";
        say "Reports will be written to $ranalysis_dir";
    }
    else {
      no warnings 'redefine';
      local *CPAN::cpanminus::reporter::RetainReports::_check_cpantesters_config_data = sub { 1 };
      $reporter->set_report_dir($ranalysis_dir);
      $reporter->run;
    }
    say "See results in $ranalysis_dir" if $verbose;
    return $ranalysis_dir;
}

sub analyze_json_logs {
    my ($self, $args) = @_;
    $args //= {};
    croak "analyze_json_logs: Must supply hash ref as argument"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';
    croak "analyze_json_logs: Must supply a 'run' number"
        unless (defined $args->{run} and length($args->{run}));
    my $srun = sprintf("%02d" => $args->{run});

    my $output = join('.' => (
        $self->{title},
        $self->{perl_version},
        $srun,
        'build',
        'log',
        'gz'
    ) );
    my $foutput = File::Spec->catfile($self->{storage_dir}, $output);
    say "Output will be: $foutput" if $verbose;

    my $vranalysis_dir = File::Spec->catdir($self->{analysis_dir}, $srun);
    opendir my $DIRH, $vranalysis_dir or croak "Unable to open $vranalysis_dir for reading";
    my @json_log_files = sort map { File::Spec->catfile('analysis', $srun, $_) }
        grep { m/\.log\.json$/ } readdir $DIRH;
    closedir $DIRH or croak "Unable to close $vranalysis_dir after reading";
    dd(\@json_log_files) if $verbose;

    my $versioned_results_dir = $self->{vresults_dir};
    chdir $versioned_results_dir or croak "Unable to chdir to $versioned_results_dir";
    my $cwd = cwd();
    say "Now in $cwd" if $verbose;

    my $tar = Archive::Tar->new;
    $tar->add_files(@json_log_files);
    $tar->write($foutput, COMPRESS_GZIP);
    croak "$foutput not created" unless (-f $foutput);
    say "Created $foutput" if $verbose;

    my %data = ();
    for my $log (@json_log_files) {
        my $flog = File::Spec->catfile($cwd, $log);
        my %this = ();
        my $f = Path::Tiny::path($flog);
        my $decoded = decode_json($f->slurp_utf8);
        map { $this{$_} = $decoded->{$_} } ( qw| author dist distname distversion grade | );
        $data{$decoded->{dist}} = \%this;
    }
    #pp(\%data);

    my $psvfile = join('.' => (
        $self->{title},
        $self->{perl_version},
        $srun,
        'psv'
    ) );

    my $fpsvfile = File::Spec->catfile($self->{storage_dir}, $psvfile);
    say "Output will be: $fpsvfile" if $verbose;

    my @fields = ( qw| author distname distversion grade | );
    my $perl_version = $self->{perl_version};
    my $columns = [
        'dist',
        map { "$perl_version.$_" } @fields,
    ];
    my $psv = Text::CSV_XS->new({ binary => 1, auto_diag => 1, sep_char => '|', eol => $/ });
    open my $OUT, ">:encoding(utf8)", $fpsvfile
        or croak "Unable to open $fpsvfile for writing";
    $psv->print($OUT, $columns), "\n" or $psv->error_diag;
    for my $dist (sort keys %data) {
        $psv->print($OUT, [
           $dist,
           @{$data{$dist}}{@fields},
        ]) or $psv->error_diag;
    }
    close $OUT or croak "Unable to close $fpsvfile after writing";
    croak "$fpsvfile not created" unless (-f $fpsvfile);
    say "Examine pipe-separated values in $fpsvfile" if $verbose;

    return $fpsvfile;
}

1;

=head1 LIMITATIONS

This library has a fair number of direct and indirect dependencies on other
CPAN libraries.  Consequently, the library may experience problems if there
are major changes in those libraries.  In particular, the code is indirectly
dependent upon F<App::cpanminus::reporter>, which in turn is dependent upon
F<cpanm>.  (Nonetheless, this software could never have been written without
those two libraries by Breno G. de Oliveira and Tatsuhiko Miyagawa,
respectively.)

=head1 AUTHOR

    James E Keenan
    CPAN ID: JKEENAN
    jkeenan@cpan.org
    http://thenceforward.net/perl

=head1 SUPPORT

This software has not yet been released to CPAN.  Until it does, you should
contact the author directly at the email address listed below.  Please contact
the author before submitting patches or pull requests.

Once the software has been released to CPAN, you should report any bugs by
mail to C<bug-Test-Against-Dev@rt.cpan.org> or through the web interface at
L<http://rt.cpan.org>.

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

Copyright James E Keenan 2017.  All rights reserved.

=head1 ACKNOWLEDGEMENTS

This library emerged in the wake of the author's participation in the Perl 5
Core Hackathon held in Amsterdam, Netherlands, in October 2017.  The author
thanks the lead organizers of that event, Sawyer X and Todd Rinaldo, for the
invitation to the hackathon.  The event could not have happened without the
generous contributions from the following companies:

=over 4

=item * L<Booking.com|https://www.booking.com>

=item * L<cPanel|https://cpanel.com>

=item * L<Craigslist|https://www.craigslist.org/about/craigslist_is_hiring>

=item * L<Bluehost|https://www.bluehost.com/>

=item * L<Assurant|https://www.assurantmortgagesolutions.com/>

=item * L<Grant Street Group|https://grantstreet.com/>

=back

=head1 SEE ALSO

perl(1). CPAN::cpanminus::reporter::RetainReports(3).  Perl::Download::FTP(3).
App::cpanminus::reporter(3).  cpanm(3).

L<2017 Perl 5 Core Hackathon Discussion on Testing|https://github.com/p5h/2017/wiki/What-Do-We-Want-and-Need-from-Smoke-Testing%3F>.

L<perl.cpan.testers.discuss Thread on Testing|https://www.nntp.perl.org/group/perl.cpan.testers.discuss/2017/10/msg4172.html>.

=cut

