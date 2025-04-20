use strict;
use warnings;
use OpenGL::Modern::Registry;
require './utils/common.pl';

=head1 PURPOSE

This script reads the function signatures from the registry
and creates XS stubs for each.

This should also autogenerate stub documentation by adding links
to the OpenGL documentation for each function via

L<https://www.opengl.org/sdk/docs/man/html/glShaderSource.xhtml>

=cut

our %signature;
*signature = \%OpenGL::Modern::Registry::registry;

=head1 Automagic Perlification

We should think about how to ideally enable the typemap
to automatically perlify the API. Or just handwrite
it for the _p functions?!

=cut

sub munge_GL_args {
    my ( @args ) = @_;

    # GLsizei n
    # GLsizei count
}

sub generate_glew_xs {
  my $content;
  for my $name (@_ ? @_ : sort keys %signature) {
    my $item = $signature{$name};
    if ( is_manual($name) ) {
      print "Skipping $name, already implemented in Modern.xs\n";
      next;
    }
    my @argdata = @{$item->{argdata} || []};
    my $glewImpl = $item->{glewImpl};
    my $error_check = $name eq "glGetError" ? "" : "OGLM_CHECK_ERR($name)";
    my $avail_check = ($item->{glewtype} eq 'fun' && $glewImpl)
      ? "  OGLM_AVAIL_CHECK($glewImpl, $name)\n"
      : "";
    my $preamble = qq{  OGLM_GLEWINIT@{[$error_check && "\n  $error_check"]}\n};
    my $callarg_list = $item->{glewtype} eq 'var' ? "" : "(@{[ join ', ', map $_->[0], @argdata ]})";
    for my $binding_name (bind_names($name, $item)) {
      my (@thisargdata, $thistype, $retcap, $retout, $thiscode) = @argdata;
      my ($beforecall, $aftercall) = ('', '');
      $thistype = $item->{restype};
      ($retcap, $retout) = $thistype eq 'void' ? ('','') : ('RETVAL = ', "\nOUTPUT:\n  RETVAL");
      $thiscode = "CODE:\n";
      my $args = join ', ', map $_->[0], @thisargdata;
      my $res = "$thistype\n$binding_name($args)\n";
      $res .= join '', map "  $_->[1]$_->[0];\n", @thisargdata;
      $res .= $thiscode . $preamble . $avail_check . $beforecall;
      $res .= qq{  $retcap$name$callarg_list;@{[$error_check && "\n  $error_check"]}};
      $content .= "$res$aftercall$retout\n\n";
    }
  }
  return $content;
}

my $xs_code = generate_glew_xs(@ARGV);
save_file( 'auto-xs.inc', $xs_code );
