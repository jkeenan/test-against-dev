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
use File::Temp ( qw| tempdir | );
use Path::Tiny;
use Perl::Download::FTP;

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
        module_file module_list
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
    system(@cmd) and croak "Unable to install modules from list";

    return 1;
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

1;

