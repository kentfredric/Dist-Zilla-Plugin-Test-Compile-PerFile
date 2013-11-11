
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.4008"
  },
  "configure_requires" => {
    "Module::Build" => "0.4008"
  },
  "dist_abstract" => "Create a single .t for each compilable file in a distribution",
  "dist_author" => [
    "Kent Fredric <kentfredric\@gmail.com>"
  ],
  "dist_name" => "Dist-Zilla-Plugin-Test-Compile-PerFile",
  "dist_version" => "0.001000",
  "license" => "perl",
  "module_name" => "Dist::Zilla::Plugin::Test::Compile::PerFile",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Dist::Zilla::File::FromCode" => 0,
    "Dist::Zilla::Plugin::FinderCode" => 0,
    "Dist::Zilla::Role::FileGatherer" => 0,
    "Dist::Zilla::Role::TextTemplate" => 0,
    "File::ShareDir" => 0,
    "Moose" => 0,
    "Moose::Util::TypeConstraints" => 0,
    "MooseX::LazyRequire" => 0,
    "Path::Tiny" => 0,
    "perl" => "5.006001",
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => [],
  "share_dir" => {
    "dist" => "share"
  },
  "test_requires" => {
    "Test::More" => "1.001002"
  }
);


my %fallback_build_requires = (
  "Module::Build" => "0.4008",
  "Test::More" => "1.001002"
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
