use strict;
use warnings;

package Dist::Zilla::Plugin::Test::Compile::PerModule;
BEGIN {
  $Dist::Zilla::Plugin::Test::Compile::PerModule::AUTHORITY = 'cpan:KENTNL';
}
{
  $Dist::Zilla::Plugin::Test::Compile::PerModule::VERSION = '0.001000';
}

# ABSTRACT: Create a single .t for each module in a distribution

use Moose;


use Path::Tiny qw(path);
use File::ShareDir qw(dist_dir);
use Moose::Util::TypeConstraints qw(enum);

has xt_mode => ( is => ro =>, isa => Bool =>, lazy_build => 1 );
has prefix  => ( is => ro =>, isa => Str  =>, lazy_build => 1 );

our %module_translators = (
    base64_filter => sub {
        my $module = shift;
        $module =~ s/[^-\p{PosixAlnum}_]+/_/g;
        return $module;
    },
);

our %templates = ();

my $dist_dir = dist_dir('Dist-Zilla-Plugin-Test-Compile-PerModule');
my $template_dir = path($dist_dir);

has module_translator => ( is => ro =>, isa => enum([sort keys %module_translators]), lazy_build => 1 );
has _module_translator => ( is => ro =>, isa => CodeRef =>, lazy_build => 1, init_arg => undef );

sub _build_xt_mode {
    return;
}

sub _build_prefix {
    my ( $self ) = @_;
    if ( $self->xt_mode ) {
        return 'xt/author/00-compile';
    }
    return 't/00-compile';
}
sub _build_module_translator {
    my ( $self ) = @_;
    return 'base64_filter';
}
sub _build__module_translator {
    my ($self) = @_;
    my $translator = $self->module_translator;
    return $module_translators{$translator};
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Test::Compile::PerModule - Create a single .t for each module in a distribution

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

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
