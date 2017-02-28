# This test was generated for <{{$file}}>
# using by {{ $plugin_module }} ( {{ $plugin_name }} ) version {{ $plugin_version }}
# with template 02-raw-require.t.tpl
my $file = "{{ quotemeta($relpath) }}";
my $err;
{
  local $@;
  eval { require $file; 1 } or $err = $@;
};

if( not defined $err ) {
  printf "1..1\nok 1 - require %s\n", $file;
  exit 0;
}
printf "1..1\nnot ok 1 - require %s\n", $file;
for my $line ( split /\n/, $err ) {
  printf STDERR "# %s\n", $line;
}
exit 1;
