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
    my $avail_check = ($item->{glewtype} eq 'fun' && $glewImpl)
      ? "  OGLM_AVAIL_CHECK($glewImpl, $name)\n"
      : "";
    my $callarg_list = $item->{glewtype} eq 'var' ? "" : "(@{[ join ', ', map $_->[0], @argdata ]})";
    for my $binding_name (bind_names($name, $item)) {
      my (@thisargdata, $thistype, $retcap, $retout, $thiscode) = @argdata;
      my ($beforecall, $aftercall) = ('', '');
      my $error_check = $name eq "glGetError" ? "" : "OGLM_CHECK_ERR($name, )";
      my $error_check2 = $error_check;
      $thistype = $item->{restype};
      $thiscode = "CODE:\n";
      if ($binding_name =~ /_p$/) {
        die "$binding_name: don't know how to bind" if $binding_name !~ /^gl(Gen|Delete)/;
        die "$binding_name: expected void, got '$item->{restype}'" if $item->{restype} ne 'void';
        die "$binding_name: expected (n, other), got '@{[join ', ', map $_->[0], @thisargdata]}'" if @argdata != 2;
        ($retcap, $retout) = $thistype eq 'void' ? ('','') : ('RETVAL = ', "\nOUTPUT:\n  RETVAL");
        pop @thisargdata;
        if ($binding_name =~ /^glGen/) {
          $thiscode = "PPCODE:\n";
          ($beforecall, $aftercall) = ("  OGLM_GEN_SETUP($name, $argdata[0][0], $argdata[1][0])\n", "\n  OGLM_GEN_FINISH($argdata[0][0], $argdata[1][0])");
        } elsif ($binding_name =~ /^glDelete/) {
          @thisargdata = ['...'];
          ($beforecall, $aftercall) = ("  GLsizei $argdata[0][0] = items;\n  OGLM_DELETE_SETUP($name, items, $argdata[1][0])\n", "\n  OGLM_DELETE_FINISH($argdata[1][0])");
        } else {
          die "$binding_name: code error, don't know how to bind";
        }
        $error_check2 = "OGLM_CHECK_ERR($name, free($argdata[1][0]))";
      } else {
        ($retcap, $retout) = $thistype eq 'void' ? ('','') : ('RETVAL = ', "\nOUTPUT:\n  RETVAL");
      }
      my $args = join ', ', map $_->[0], @thisargdata;
      my $res = "$thistype\n$binding_name($args)\n";
      $res .= join '', map "  $_->[1]$_->[0];\n", @thisargdata unless @thisargdata == 1 && $thisargdata[0][0] eq '...';
      $res .= $thiscode . "  OGLM_GLEWINIT\n";
      $res .= "  $error_check\n" if $error_check;
      $res .= $avail_check . $beforecall;
      $res .= qq{  $retcap$name$callarg_list;};
      $res .= "\n  $error_check2" if $error_check2;
      $content .= "$res$aftercall$retout\n\n";
    }
  }
  return $content;
}

my $xs_code = generate_glew_xs(@ARGV);
save_file( 'auto-xs.inc', $xs_code );
