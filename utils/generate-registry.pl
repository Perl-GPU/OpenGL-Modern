use strict;
use warnings;

=head1 PURPOSE

This script extracts the function signatures etc from include/GL/glew.h
and saves the info to lib/OpenGL/Modern/Registry.pm

=cut

my %upper2data;
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
        elsif ( defined( $feature_name ) and $line =~ m|^#endif /\* $feature_name \*/\s*| ) {

            # End of lines for this OpenGL feature
            $feature_name = undef;

            # typedef void* (GLAPIENTRY * PFNGLMAPBUFFERPROC) (GLenum target, GLenum access);
            # typedef void (GLAPIENTRY * PFNGLGETQUERYIVPROC) (GLenum target, GLenum pname, GLint* params);
        }
        elsif ( $line =~ m|^typedef (\w+(?:\s*\*)?) \(GLAPIENTRY \* PFN(\w+)PROC\)\s*\((.*)\);| ) {
            my ( $restype, $name, $sig ) = ( $1, $2, $3 );
            my $s =
              { signature => $sig, restype => $restype, name => $name, glewtype => 'fun' };
            $s->{feature} = $feature_name if $feature_name;
            $upper2data{$name} = $s;

            # GLAPI void GLAPIENTRY glClearColor (GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha);
        }
        elsif ( $line =~ m|^GLAPI ([\w* ]+?) GLAPIENTRY (\w+) \((.*)\);| ) {

            # Some external function, likely imported from libopengl / opengl32
            my ( $restype, $name, $sig ) = ( $1, $2, $3 );
            my $s =
              { signature => $sig, restype => $restype, name => $name, glewtype => 'fun' };
            $s->{feature} = $feature_name if $feature_name;
            $upper2data{ uc $name } = $s;
            $case_map{ uc $name }  = $name;

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
            my $s = { signature => 'void', restype => $restype, glewtype => 'var' };
            $s->{feature} = $feature_name if $feature_name;
            my $name = $alias{$impl};
            $upper2data{$name} = $s;
            $case_map{$name} = $impl;

        }
    }
}

my %signature;
# Now rewrite the names to proper case when we only have their uppercase alias
for my $name ( sort {uc$a cmp uc$b} keys %upper2data ) {
    my $impl      = $case_map{$name} || $name;
    my $real_name = $alias{$impl}    || $impl;
    my $s = $upper2data{$name};
    $signature{$real_name} = $s;
    delete $s->{name};
    push @{ $features{$s->{feature}} }, $real_name if $s->{feature};
}

sub preprocess_for_registry {
    for my $name (@_ ? @_ : sort keys %signature) {
        my $item = $signature{$name};
        next if $manual{$name};
        my $args = delete $item->{signature};
        die "No args for $name" unless $args;
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
        $item->{argdata} = \@argdata if @argdata;
        my $glewImpl;
        if ( ($item->{feature}//'') ne "GL_VERSION_1_1" ) {
            ( $glewImpl = $name ) =~ s!^gl!__glew!;
        }
        $item->{glewImpl} = $glewImpl;
        # Determine any name suffixes
        # All routines with * or [] in the return value or arguments
        # have a '_c' suffix variant.
        # Track number of pointer type args/return values (either * or [])
        my $type = $item->{restype};
        my $num_ptr_types = ( $type =~ tr/*[/*[/ ) + grep $_->[1] =~ /\*/, @argdata;
        $item->{binding_name} = $name . '_c' if $num_ptr_types > 0;
        push @exported_functions, $num_ptr_types > 0 ? $name . '_c' : $name;
    }
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

# Now rewrite registry if we need to:
my $glFunctions = join '', "\n", map "  $_\n", sort {uc$a cmp uc$b} @exported_functions;
use Data::Dumper;
$Data::Dumper::Indent = $Data::Dumper::Sortkeys = $Data::Dumper::Terse = 1;
my $gltags = Dumper \%features;
$gltags =~ s!^\{!!;
$gltags =~ s!\s+\}$!!s;
my $new = <<"END";
package OpenGL::Modern::Registry;

# ATTENTION: This file is automatically generated by utils/generate-registry.pl
#            Manual changes will be lost.
use strict;
use warnings;

sub gl_functions {qw($glFunctions)}

sub EXPORT_TAGS_GL {($gltags)}

END
my $registry = Dumper \%signature;
$registry =~ s!^\{!!;
$registry =~ s!\s+\}$!!s;
$new .= "our %registry = ($registry);\n";
$new .= "1;\n";
save_file( "lib/OpenGL/Modern/Registry.pm", $new );
