use strict;
use warnings;

=head1 PURPOSE

This script extracts the function signatures etc from include/GL/glew.h
and saves the info to lib/OpenGL/Modern/Registry.pm

=cut

require './utils/common.pl';
my %upper2data;
my %case_map;
my %alias;

my @exported_functions = manual_list(); # names the module exports
my %constants;

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

            # #define GL_CONSTANT_NAME ...
        }
        elsif ( $line =~ m|^#define (GL(?:EW)?_\w+)\s+\S| ) {
            my $c = $1;
            $constants{$c} = undef if $c !~ /_EXPORT$/;

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
for my $name ( keys %upper2data ) {
  my $impl      = $case_map{$name} || $name;
  my $real_name = $alias{$impl}    || $impl;
  my $s = $upper2data{$name};
  $signature{$real_name} = $s;
  delete $s->{name};
}

sub preprocess_for_registry {
    for my $name (@_ ? @_ : sort keys %signature) {
        my $item = $signature{$name};
        next if is_manual($name);
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
        $item->{has_ptr_arg} = 1 if $num_ptr_types > 0;
    }
}

preprocess_for_registry(@ARGV);

my %feature2version;
for (grep $_, split /\n/, slurp('utils/feature-reuse.txt')) {
  my ($v, $f) = split /\s+/;
  $feature2version{$f}{$v} = undef;
}
@feature2version{keys %feature2version} = map +(keys %$_)[0], values %feature2version;
$signature{$_}{core_removed} = 1 for grep $_, split /\s+/, slurp('utils/removed.txt');
my (%features, %gltags);
for my $name (sort {uc$a cmp uc$b} keys %signature) {
  my $s = $signature{$name};
  my $binding_name = $s->{has_ptr_arg} ? $name . '_c' : $name;
  push @exported_functions, $binding_name if !is_manual($name);
  next if !$s->{feature};
  for ($s->{feature}, grep defined, $feature2version{$s->{feature}}) {
    $gltags{$_}{$binding_name} = undef;
    $features{$_}{$name} = undef;
  }
}
@gltags{keys %gltags} = map [sort keys %$_], values %gltags;
@features{keys %features} = map [sort keys %$_], values %features;
my @version_features = grep /^GL_VERSION/, keys %features;
my (@version_31, @version_core);
for my $f (@version_features) {
  die "Error parsing '$f'" unless my ($maj, $min) = $f =~ /(\d)/g;
  my $arr = (10*$maj + $min) < 32 ? \@version_31 : \@version_core;
  push @$arr, $f;
}
my %glcompat_c = map +($_=>undef), map @{$gltags{$_}}, @version_31;

# Now rewrite registry if we need to:
use Data::Dumper;
$Data::Dumper::Indent = $Data::Dumper::Sortkeys = $Data::Dumper::Terse = 1;
my $new = <<"END";
package OpenGL::Modern::Registry;\n
# ATTENTION: This file is automatically generated by utils/generate-registry.pl
#            Manual changes will be lost.
use strict;
use warnings;\n
END
my $registry = Dumper \%signature;
$registry =~ s!^\{!!;
$registry =~ s!\s+\}$!!s;
$new .= "our %registry = ($registry);\n\n";
my $glconstants = join '', "\n", map "  $_\n", sort keys %constants;
$new .= "our \@glconstants = qw($glconstants);\n\n";
my $features = Dumper \%features;
$features =~ s!^\{!!;
$features =~ s!\s+\}$!!s;
$new .= "our %features = ($features);\n\n";
$new .= "1;\n";
save_file( "lib/OpenGL/Modern/Registry.pm", $new );

my $orig = slurp("lib/OpenGL/Modern.pm");
my $sep = "# OGLM INSERT SEPARATOR\n";
my ($start, undef, $end) = split $sep, $orig;
my $middle = "# BEGIN code generated by utils/generate-registry.pl\n";
my $gl_functionscompat = join '', "\n", map "  $_\n", sort grep exists $glcompat_c{$_}, @exported_functions;
$middle .= "our \@gl_functionscompat = qw($gl_functionscompat);\n";
my $gl_functionsrest = join '', "\n", map "  $_\n", sort {uc$a cmp uc$b} grep !exists $glcompat_c{$_}, @exported_functions;
$middle .= "our \@gl_functionsrest = qw($gl_functionsrest);\n";
my $gltags = Dumper \%gltags;
$gltags =~ s!^\{!!;
$gltags =~ s!\s+\}$!!s;
$middle .= "our %EXPORT_TAGS_GL = ($gltags);\n";
$middle .= "our \@gl_constants = qw($glconstants);\n\n";
$middle .= "# END code generated by utils/generate-registry.pl\n";
$new = join $sep, $start, $middle, $end;
save_file( "lib/OpenGL/Modern.pm", $new );
