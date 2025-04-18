use strict;
use warnings;
use OpenGL::Modern::Registry;

=head1 PURPOSE

This script reads the function signatures from the registry
and creates XS stubs for each.

This should also autogenerate stub documentation by adding links
to the OpenGL documentation for each function via

L<https://www.opengl.org/sdk/docs/man/html/glShaderSource.xhtml>

=cut

# The functions where we specify manual implementations or prototypes
# These could also be read from Modern.xs, later maybe
my @manual_list = qw(
  glGetString
  glShaderSource_p
);

my %manual;
@manual{@manual_list} = ( 1 ) x @manual_list;
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
        if ( $manual{$name} ) {
            print "Skipping $name, already implemented in Modern.xs\n";
            next;
        }
        my $argdata = $item->{argdata};
        my @argdata = @{$argdata || []};
        my $type = $item->{restype};
        my $no_return_value = $type eq 'void';
        my $glewImpl = $item->{glewImpl};
        my $args = join ', ', map $_->[0], @argdata;
        my $xs_args = join '', map "     $_->[1]$_->[0];\n", @argdata;
        my $binding_name = $item->{binding_name};
        my $decl = <<XS;
$type
$binding_name($args);
XS
        $decl .= $xs_args;
        my $error_check = $name eq "glGetError" ? "" : "OGLM_CHECK_ERR($name)";
        my $res = $decl . <<XS;
CODE:
    OGLM_GLEWINIT@{[$error_check && "\n    $error_check"]}
XS
        if ( $item->{glewtype} eq 'fun' and $glewImpl ) {
            $res .= "    OGLM_AVAIL_CHECK($glewImpl, $name)\n";
        }
        if ( $no_return_value ) {
            $res .= <<XS;
    $name($args);@{[$error_check && "\n    $error_check"]}
XS
        }
        else {
            my $arg_list = $item->{glewtype} eq 'var' ? "" : "($args)";
            $res .= <<XS;
    RETVAL = $name$arg_list;@{[$error_check && "\n    $error_check"]}
OUTPUT:
    RETVAL
XS
        }
        $content .= "$res\n";
    }
    return $content;
}

sub slurp {
    my $filename = $_[0];
    open my $old_fh, '<:raw', $filename
      or die "Couldn't read '$filename': $!";
    join '', <$old_fh>;
}

sub save_file {
    my ( $filename, $new ) = @_;
    my $old = -e $filename ? slurp( $filename ) : "";
    if ( $new ne $old ) {
        print "Saving new version of $filename\n";
        open my $fh, '>:raw', $filename
          or die "Couldn't write new version of '$filename': $!";
        print $fh $new;
    }
}

my $xs_code = generate_glew_xs(@ARGV);
save_file( 'auto-xs.inc', $xs_code );
