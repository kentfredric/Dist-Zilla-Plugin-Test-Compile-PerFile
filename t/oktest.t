use strict;
use warnings;

use Test::More;
use Test::File::ShareDir::Dist { 'Dist-Zilla-Plugin-Test-Compile-PerFile' => 'share' };
use Dist::Zilla::Util::Test::KENTNL 1.003002 qw( dztest );
use Test::DZil qw( simple_ini );
use Capture::Tiny qw( capture_merged );

# ABSTRACT: Basic test

my $t = dztest();

$t->add_file( 'dist.ini', simple_ini( ['GatherDir'], ['Test::Compile::PerFile'], ['MakeMaker'], ) );

$t->add_file( 'lib/Good.pm', <<'EOF');
package Good;

# This is a good file

1
EOF

my $merged = capture_merged {
  $t->configure->test;
};

like( $merged, qr/Result: PASS/, 'Running tests gives pass' );
note explain $merged;

done_testing;
