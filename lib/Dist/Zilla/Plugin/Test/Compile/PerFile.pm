use strict;
use warnings;

package Dist::Zilla::Plugin::Test::Compile::PerFile;
BEGIN {
  $Dist::Zilla::Plugin::Test::Compile::PerFile::AUTHORITY = 'cpan:KENTNL';
}
{
  $Dist::Zilla::Plugin::Test::Compile::PerFile::VERSION = '0.001000';
}

# ABSTRACT: Create a single .t for each compilable file in a distribution

use Moose;
use MooseX::LazyRequire;

with 'Dist::Zilla::Role::FileGatherer', 'Dist::Zilla::Role::TextTemplate';


use Path::Tiny qw(path);
use File::ShareDir qw(dist_dir);
use Moose::Util::TypeConstraints qw(enum);

has xt_mode => ( is => ro =>, isa => Bool =>, lazy_build => 1 );
has prefix  => ( is => ro =>, isa => Str  =>, lazy_build => 1 );

our %path_translators = (
  base64_filter => sub {
    my $module = shift;
    $module =~ s/[^-\p{PosixAlnum}_]+/_/g;
    return $module;
  },
  mimic_source => sub {
    return $_[0];
  }
);

our %templates = ();

my $dist_dir     = dist_dir('Dist-Zilla-Plugin-Test-Compile-PerModule');
my $template_dir = path($dist_dir);
for my $file ( $template_dir->children ) {
  next if $file =~ /\A\./msx;    # Skip hidden files
  next if -d $file;              # Skip directories
  $templates{ $file->basename } = $file;
}

around mvp_multivalue_args => sub {
    my ( $orig, $self, @args ) = @_;
    return ( 'finder', 'file', 'files', $self->$orig(@args) );
};

around mvp_aliases => sub {
  my ( $orig, $self, @args ) = @_;
  my $hash = $self->$orig( @args );
  $hash = {} if not defined $hash;
  $hash->{ file  } = 'files';
  return $hash;
};

has path_translator => ( is => ro =>, isa => enum( [ sort keys %path_translators ] ), lazy_build => 1 );
has _path_translator => ( is => ro =>, isa => CodeRef =>, lazy_build => 1, init_arg => undef );
has test_template => ( is => ro =>, isa => enum( [ sort keys %templates ] ), lazy_build => 1 );
has _test_template => ( is => ro =>, isa => Defined =>, lazy_build => 1, init_arg => undef );
has _test_template_content => ( is => ro =>, isa => Defined =>, lazy_build => 1, init_arg => undef );
has file => ( is => ro =>, isa => 'ArrayRef[Str]', lazy_build => 1, );
has finder => ( is => ro =>, isa => 'ArrayRef[Str]', lazy_required => 1 , predicate => 'has_finder' );
has _finder_objects => ( is => ro =>, isa => 'ArrayRef', lazy_build => 1, init_arg => undef );

sub _build_xt_mode {
  return;
}

sub _build_prefix {
  my ($self) = @_;
  if ( $self->xt_mode ) {
    return 'xt/author/00-compile';
  }
  return 't/00-compile';
}

sub _build_path_translator {
  my ($self) = @_;
  return 'mimic_source';
}

sub _build__path_translator {
  my ($self) = @_;
  my $translator = $self->path_translator;
  return $path_translators{$translator};
}

sub _build_test_template {
  return '01-basic.t.tpl';
}

sub _build__test_template {
  my ($self) = @_;
  my $template = $self->test_template;
  return $templates{$template};
}
sub _build__test_template_content {
    my ( $self ) = @_;
    my $template = $self->_test_template;
    return $template->slurp_utf8;
}
sub _build_file {
    my ( $self ) = @_;
    return [ map { $_->name } @{ $self->_found_files } ];
}

sub gather_files {
    my ( $self ) = @_;
    require Dist::Zilla::File::FromCode;

    my $prefix = $self->prefix;
    $prefix =~ s{/?\z}{/}msx;

    my $translator = $self->_path_translator;

    my $template;

    if ( not @{ $self->file } ) {
        $self->log_debug("Did not find any files to add tests for, did you add any files yet?");
        return;
    }
    for my $file ( @{ $self->file } ) {
        my $name = $prefix . $translator->($file) . '.t';
        $self->log_debug("Adding $name for $file");
        $self->add_file(Dist::Zilla::File::FromCode->new(
            name => $name,
            code_return_type => 'text',
            code => sub {
                $template = $self->_test_template_content if not defined $template;
                return $self->fill_in_string($template, { 
                        file => $file,
                        plugin_module => $self->meta->name, 
                        plugin_name   => $self->plugin_name,
                        plugin_version       => ( $self->VERSION ? $self->VERSION : '<self>' ),
                        test_more_version => '0.89',
                });
            }
        ));
    }

}

sub _build__finder_objects {
    my ($self) = @_;
    if ( $self->has_finder ) {
        my @out;
        for my $finder ( @{ $self->finder } ) {
            my $plugin = $self->zilla->plugin_named($finder);
            if ( not $plugin ) {
                $self->log_fatal("no plugin named $finder found");
            }
            if ( not $plugin->does('Dist::Zilla::Role::FileFinder') ) {
                $self->log_fatal("plugin $finder is not a FileFinder");
            }
            push @out, $plugin;
        }
        return \@out;
    }
    return [ $self->_vivify_installmodules_pm_finder ];
}

sub _vivify_installmodules_pm_finder {
    my ($self) = @_;
    my $name = $self->plugin_name;
    $name .= '/AUTOVIV/:InstallModulesPM';
    if ( my $plugin = $self->zilla->plugin_named($name) ) {
        return $plugin;
    }
    require Dist::Zilla::Plugin::FinderCode;
    my $plugin = Dist::Zilla::Plugin::FinderCode->new(
        {
            plugin_name => $name,
            zilla       => $self->zilla,
            style       => 'grep',
            code        => sub {
                my ( $file, $self ) = @_;
                local $_ = $file->name;
                ## no critic (RegularExpressions)
                return 1 if m{\Alib/} and m{\.(pm)$};
                return 1 if $_ eq $self->zilla->main_module;
                return;
            },
        }
    );
    push @{ $self->zilla->plugins }, $plugin;
    return $plugin;
}
sub _found_files {
    my ($self) = @_;
    my %by_name;
    for my $plugin ( @{ $self->_finder_objects } ) {
        for my $file ( @{ $plugin->find_files } ) {
            $by_name{ $file->name } = $file;
        }
    }
    return [ values %by_name ];
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Test::Compile::PerFile - Create a single .t for each compilable file in a distribution

=head1 VERSION

version 0.001000

=head1 DESCRIPTION

This module is inspired by its earlier sibling L<< C<[Test::Compile]>|Dist::Zilla::Plugin::Test::Compile >>.

Test::Compile is awesome, however, in the process of its development, we discovered it might be useful
to run compilation tests in parallel.

This lead to the realisation that implementing said functions are kinda messy.

However, a further realisation is, that parallelism should not be codified in the test itself, because platform parallelism is rather not very portable, so parallelism should only be enabled when asked for.

And this lead to the realisation that C<prove> and C<Test::Harness> B<ALREADY> implement parallelism, and B<ALREADY> provide a safe way for platforms to indicate parallelism is wanted.

Which means implementing another layer of parallelism is unwanted and unproductive effort ( which may be also filled with messy parallelism-induced bugs )

So, here is the Test::Compile model based on how development is currently proceeding.

    prove 
      \ ----- 00_compile.t
     |           \ ----- Compile Module 1
     |           \ ----- Compile Module 2
     |
     \ ----- 01_basic.t

That may be fine for some people, but this approach has several fundemental limits:

=over 4

=item 1. Sub-Tasks of compile don't get load balanced by the master harness.

=item 2. Parallelism is developer side, not deployment side governed.

=item 3. This approach means C<prove -s> will have no impact.

=item 4. This approach means C<prove -j> will have no impact.

=item 5. This approach means other features of C<prove> such as the C<--state=slow>

=back

So this variation aims to employ one test file per module, to leverage C<prove> power.

One initial concern cropped up on the notion of having excessive numbers of perl instances, ie:

    prove 
      \ ----- 00_compile/01_Module_1.t
     |           \ ----- Compile Module 1
     |
      \ ----- 00_compile/02_Module_2.t
     |           \ ----- Compile Module 2
     |
     \ ----- 01_basic.t

If we were to implement it this way, we'd have the fun overhead of having to spawn B<2> C<perl> instances
per module tested, which on C<Win32>, would roughly double the test time and give nothing in return.

However, B<Most> of the reason for having a perl process per compile, was to seperate the modules from each other
to assure they could be loaded independently.

So because we already have a basically empty compile-state per test, we can reduce the number of C<perl> processes to as many modules as we have.

    prove 
      \ ----- 00_compile/01_Module_1.t
     |
      \ ----- 00_compile/02_Module_2.t
    |
     \ ----- 01_basic.t

Granted, there is still some blead here, because doing it like this means you have some modules pre-loaded prior to compiling the module in question, namely, that C<Test::*> will be in scope.

However, "testing these modules compile without C<Test::> loaded" is not the real purpose of the compile tests,
the compile tests are to make sure the modules load.

So this is an acceptable caveat for this module, and if you wish to be distinct from C<Test::*>, then you're encouraged to use the much more proven C<[Test::Compile]>.

Though we may eventually provide an option to spawn additional perl processes to more closely mimic C<Test::*>'s behaviour, the cost of doing so should not be understated, and as this module exist to attempt to improve efficiency of tests, not to decrease them, that would be an approach counter-productive to this modules purpose.

=head1 Other Important Differences to Test::Compile

=head2 Finders useful, but not required

C<[Test::Compile::PerFile]> supports providing an arbitrary list of files to generate compile tests

    [Test::Compile::PerFile]
    file = lib/Foo.pm
    file = lib/Quux.pm

Using this will supercede using finders to find things.

=head2 Single finder only, not multiple

C<[Test::Compile]> supports 2 finder keys, C<module_finder> and C<script_finder>.

This module only supports one key, C<finder>, and it is expected
that if you want to test 2 different sets of files, you'll create a seperate instance for that:

    -[Test::Compile]
    -module_finder = Foo
    -script_finder = bar
    +[Test::Compile::PerFile / module compile tests]
    +finder = Foo
    +[Test::Compile::PerFile / script compile tests]
    +finder = bar

This is harder to do with C<[Test::Compile]>, because you'd have to declare a seperate file name for it to work,
where-as C<[Test::Compile::PerFile]> generates a unique filename for each source it tests.

Collisions are still possible, but harder to hit by accident.

=head1 Performance

A rough comparison on the C<dzil> git tree, with C<HARNESS_OPTIONS=j4:c> where C<4> is the number of logical CPUs I have:

    Test::Compile -            Files= 42, Tests=577, 57 wallclock secs ( 0.32 usr  0.11 sys + 109.29 cusr 11.13 csys = 120.85 CPU)
    Test::Compile::PerFile -   Files=176, Tests=576, 44 wallclock secs ( 0.83 usr  0.39 sys + 127.34 cusr 13.27 csys = 141.83 CPU)

So a 20% saving for a 300% growth in file count, a 500k growth in unpacked tar size, and a 4k growth in tar.gz size.

Hm, thats a pretty serious trade off. Might not really be worth the savings.

Though, comparing compile tests alone:

    # Test::Compile
    prove -j4lr --timer t/00-compile.t
    Files=1, Tests=135, 41 wallclock secs ( 0.07 usr  0.01 sys + 36.82 cusr  3.58 csys = 40.48 CPU)

    # Test::Compile::PerFile
    prove -j4lr --timer t/00-compile/
    Files=135, Tests=135, 22 wallclock secs ( 0.58 usr  0.32 sys + 64.45 cusr  6.74 csys = 72.09 CPU)

Thats not bad, considering that although I have 4 logical CPUS, thats really just 2 physical cpus with hyperthreading ;)

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
