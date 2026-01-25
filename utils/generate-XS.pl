use strict;
use warnings;
use OpenGL::Modern::Registry;
require './utils/common.pl';

=head1 PURPOSE

This script reads the function signatures from the registry
and creates XS stubs for each.

=cut

our %signature;
*signature = \%OpenGL::Modern::Registry::registry;

sub generate_glew_xs {
  my $content;
  my $g2c2s = assemble_enum_groups(\%OpenGL::Modern::Registry::groups, \%OpenGL::Modern::Registry::counts);
  for my $name (@_ ? @_ : sort keys %signature) {
    my $item = $signature{$name};
    for my $s (bindings($name, $item, $g2c2s)) {
      die "Error generating for $name: no return type" if !$s->{xs_rettype};
      my $res = "$s->{xs_rettype}\n$s->{binding_name}($s->{xs_args})\n";
      $res .= $s->{xs_argdecls};
      $res .= "$s->{aliases}$s->{xs_code}  OGLM_GLEWINIT\n";
      $res .= "  $s->{error_check}\n" if $s->{error_check};
      $res .= $s->{avail_check} . $s->{beforecall};
      $res .= "  $s->{retcap}$name$s->{callarg_list};";
      $res .= "\n  $s->{error_check2}" if $s->{error_check2};
      $content .= "$res$s->{aftercall}$s->{retout}\n\n";
    }
  }
  $content;
}

my $xs_code = generate_glew_xs(@ARGV);
save_file( 'auto-xs.inc', $xs_code );
