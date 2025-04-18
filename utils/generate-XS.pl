use strict;
use warnings;

=head1 PURPOSE

This script extracts the function signatures from glew-2.0.0/include/GL/glew.h
and creates XS stubs for each.

This should also autogenerate stub documentation by adding links
to the OpenGL documentation for each function via

L<https://www.opengl.org/sdk/docs/man/html/glShaderSource.xhtml>

Also, it should parse the feature groups of OpenGL and generate a data structure
that shows which features are associated with which functions.

=cut

my %signature;
my %case_map;
my %alias;

# The functions where we specify manual implementations or prototypes
# These could also be read from Modern.xs, later maybe
my @manual_list = qw(
  glGetString
  glShaderSource_p
);

my %manual;
@manual{@manual_list} = ( 1 ) x @manual_list;
my @exported_functions = @manual_list; # names the module exports
my %features;

for my $file ("include/GL/glew.h") {

    my $feature_name;

    print "Processing file $file\n";

    open my $fh, '<', $file
      or die "Couldn't read '$file': $!";

    while ( my $line = <$fh> ) {
        if ( $line =~ m|^#define (\w+) 1\r?$| and $1 ne 'GL_ONE' and $1 ne 'GL_TRUE' ) {
            $feature_name = $1;

            # #endif /* GL_FEATURE_NAME */
        }
        elsif ( defined( $feature_name ) and $line =~ m|^#endif /* $feature_name */$| ) {

            # End of lines for this OpenGL feature
            $feature_name = undef;

            # typedef void* (GLAPIENTRY * PFNGLMAPBUFFERPROC) (GLenum target, GLenum access);
            # typedef void (GLAPIENTRY * PFNGLGETQUERYIVPROC) (GLenum target, GLenum pname, GLint* params);
        }
        elsif ( $line =~ m|^typedef (\w+(?:\s*\*)?) \(GLAPIENTRY \* PFN(\w+)PROC\)\s*\((.*)\);| ) {
            my ( $restype, $name, $sig ) = ( $1, $2, $3 );
            my $s =
              { signature => $sig, restype => $restype, feature => $feature_name, name => $name, glewtype => 'fun' };
            $signature{$name} = $s;
            push @{ $features{$feature_name} }, $s;

            # GLAPI void GLAPIENTRY glClearColor (GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha);
        }
        elsif ( $line =~ m|^GLAPI ([\w* ]+?) GLAPIENTRY (\w+) \((.*)\);| ) {

            # Some external function, likely imported from libopengl / opengl32
            my ( $restype, $name, $sig ) = ( $1, $2, $3 );
            my $s =
              { signature => $sig, restype => $restype, feature => $feature_name, name => $name, glewtype => 'fun' };
            $signature{ uc $name } = $s;
            $case_map{ uc $name }  = $name;
            push @{ $features{$feature_name} }, $s;

            # GLEW_FUN_EXPORT PFNGLACTIVETEXTUREPROC __glewActiveTexture;
        }
        elsif ( $line =~ m|^GLEW_FUN_EXPORT PFN(\w+)PROC __(\w+)| ) {
            my ( $name, $impl ) = ( $1, $2 );
            $case_map{$name} = $impl;

            # #define glCopyTexSubImage3D GLEW_GET_FUN(__glewCopyTexSubImage3D)
        }
        elsif ( $line =~ m|^#define (\w+) GLEW_GET_FUN\(__(\w+)\)| ) {
            my ( $name, $impl ) = ( $1, $2 );
            $alias{$impl} = $name;

            # #define GLEW_VERSION_1_1 GLEW_GET_VAR(__GLEW_VERSION_1_1)
        }
        elsif ( $line =~ m|^#define (\w+) GLEW_GET_VAR\(__(\w+)\)| ) {
            my ( $name, $impl ) = ( $1, $2 );
            $alias{$impl} = $name;

            # GLEW_VAR_EXPORT GLboolean __GLEW_VERSION_1_1;
        }
        elsif ( $line =~ m|^GLEW_VAR_EXPORT (\w+) __(\w+)| ) {
            my ( $restype, $impl ) = ( $1, $2 );
            my $s = { signature => 'void', restype => $restype, feature => $feature_name, glewtype => 'var' };
            my $name = $alias{$impl};
            $signature{$name} = $s;
            push @{ $features{$feature_name} }, $s;
            $case_map{$name} = $impl;

        }
    }
}

# Now rewrite the names to proper case when we only have their uppercase alias
for my $name ( keys %signature ) {
    my $impl      = $case_map{$name} || $name;
    my $real_name = $alias{$impl}    || $impl;
    my $s = $signature{$name};
    $s->{name} = $real_name;
}

# use Data::Dump qw(pp);
# pp(values %signature);

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

sub preprocess_for_registry {
    for my $upper (@_ ? @_ : sort keys %signature) {
        my $item = $signature{$upper};
        my $name = $item->{name};
        next if $manual{$name};
        my $args = $item->{signature};
        die "No args for $upper" unless $args;
        my @argdata;
        $args = '' if $args eq 'void';
        for (split /\s*,\s*/, $args) {
            s/\s+$//;
            s!\bGLsync(\s+)GLsync!GLsync$1myGLsync!g; # rewrite
            # Rewrite `const GLwhatever foo[]` into `const GLwhatever* foo`
            s!^const (\w+)\s+(\**)(\w+)\[\d*\]$!const $1 * $2$3!;
            s!^(\w+)\s+(\**)(\w+)\[\d*\]$!$1 * $2$3!;
            /(.*?)(\w+)$/;
            push @argdata, [$2,$1]; # name, type
        }
        $item->{argdata} = \@argdata;
        my $glewImpl;
        if ( $item->{feature} ne "GL_VERSION_1_1" ) {
            ( $glewImpl = $name ) =~ s!^gl!__glew!;
        }
        $item->{glewImpl} = $glewImpl;
        # Determine any name suffixes
        # All routines with * or [] in the return value or arguments
        # have a '_c' suffix variant.
        # Track number of pointer type args/return values (either * or [])
        my $type = $item->{restype};
        my $num_ptr_types = ( $type =~ tr/*[/*[/ ) + grep $_->[1] =~ /\*/, @argdata;
        $item->{binding_name} = my $binding_name = ( $num_ptr_types > 0 ) ? $name . '_c' : $name;
        push @exported_functions, $binding_name;
    }
}

sub generate_glew_xs {
    my $content;
    for my $upper (@_ ? @_ : sort keys %signature) {
        my $item = $signature{$upper};
        my $name = $item->{name};
        if ( $manual{$name} ) {
            print "Skipping $name, already implemented in Modern.xs\n";
            next;
        }
        my $argdata = $item->{argdata};
        die "No argdata for $upper" unless $argdata;
        my $type = $item->{restype};
        my $no_return_value = $type eq 'void';
        my $glewImpl = $item->{glewImpl};
        my $args = join ', ', map $_->[0], @$argdata;
        my $xs_args = join '', map "     $_->[1]$_->[0];\n", @$argdata;
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

preprocess_for_registry(@ARGV);
my $xs_code = generate_glew_xs(@ARGV);
save_file( 'auto-xs.inc', $xs_code );

# Now rewrite registry if we need to:
my $glFunctions = join '', "\n", map "  $_\n", @exported_functions;
my %glGroups = map {
  $_ => [ map { $_->{name} } @{ $features{$_} } ],
} keys %features;
use Data::Dumper;
$Data::Dumper::Indent = $Data::Dumper::Sortkeys = $Data::Dumper::Terse = 1;
my $gltags = Dumper \%glGroups;
$gltags =~ s!^\{!!;
$gltags =~ s!\s+\}$!!s;
my $new = <<"END";
package OpenGL::Modern::Registry;

# ATTENTION: This file is automatically generated by utils/generate-XS.pl!
#            Manual changes will be lost.

sub gl_functions {qw($glFunctions)}

sub EXPORT_TAGS_GL {($gltags)}

END
$new .= "1;\n";
save_file( "lib/OpenGL/Modern/Registry.pm", $new );
