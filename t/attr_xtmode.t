use strict;
use warnings;

use Test::More;
use Test::File::ShareDir::Dist { 'Dist-Zilla-Plugin-Test-Compile-PerFile' => 'share' };
use Dist::Zilla::Util::Test::KENTNL 1.003002 qw( dztest );
use Test::DZil qw( simple_ini );

# ABSTRACT: Basic test

my $t = dztest();

$t->add_file( 'dist.ini', simple_ini( ['GatherDir'], [ 'Test::Compile::PerFile', { xt_mode => 1 } ], ) );

$t->add_file( 'lib/Good.pm', <<'EOF');
package Good;

# This is a good file

1
EOF

$t->build_ok;

$t->test_has_built_file('xt/author/00-compile/lib_Good_pm.t');

done_testing;
