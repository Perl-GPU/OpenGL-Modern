package    # not an official package
  OpenGL::Modern::Helpers;

our $VERSION = '0.0401';

use strict;
use Exporter 'import';
use Carp qw(croak);
use Config;

use OpenGL::Modern qw(
  GL_VERSION
  glGenTextures_p
  glGenFramebuffers_p
  glGenVertexArrays_p
  glGenBuffers_p
  glGetString
  glpCheckErrors
  glGetShaderInfoLog_p
  glGetProgramInfoLog_p
  glGetProgramiv_p
  glGetShaderiv_p
  glGetIntegerv_p
  glShaderSource_p
  glBufferData_c
  glUniform2f
  glUniform4f
);

=head1 NAME

OpenGL::Modern::Helpers - example usage of raw pointers from perl

=head1 WARNING

This API is an experiment and will change!

=head1 OpenGL::Modern API Implementation

This module exists to support the use of the OpenGL::Modern
package for OpenGL bindings by documenting details of the
implementation and giving example routines showing the
use from perl.

=head2 Implementation

OpenGL::Modern is an XS module providings bindings to the
C OpenGL library for graphics.  As such, it needs to handle
conversion of input arguments from perl into the required
datatypes for the C OpenGL API, it then calls the OpenGL
routine, and then converts the return value (if any) from
the C API datatype into an appropriate Perl type.

=head3 Scalar Values

Routines that take scalar values and return scalar
values at the C level, are nicely mapped by the built in
typemap conversions.  For example:

  GLenum
  glCheckNamedFramebufferStatus(GLuint framebuffer, GLenum target);

where the functions takes two values, one an integer and
one an enumeration which is basically an integer value
as well.  The return value is another enumeration/integer
value.  Since perl scalars can hold integers, the default
XS implementation from perl would be prototyped in perl
as

  $status = glCheckNamedFramebufferStatus($framebuffer, $target);

or, taking advantage of the binding of all the OpenGL
enumerations to perl constant functions we could write

  $status = glCheckNamedFramebufferStatus($framebuffer, GL_DRAW_FRAMEBUFFER);

The key here is explicit scalar values and types which makes
the XS perl implementation essentially the same at the C one
just with perl scalars in place of C typed values.
Of the 2743 OpenGL API routines, 1092 have scalar input
and return values and can be considered implemented as
is.

=head3 Pointer Values

The remaining OpenGL routines all have one (or more)
pointer argument or return value which are not so
simply mapped into perl because the use of pointers
from C does not fully determine the use of those
values:

=over 4

=item *
Pointers can be used to return values from routines

=item *
Pointers can be used to pass single input values

=item *
Pointers can be used to pass multiple input values

=item *
Pointers can be used to return multiple input values

=back

The current XS implementation now represents non-char
type pointers as the typemap T_PTR and the string and
character pointers are T_PV.  The routines will be
renamed with an added _c so as to indicate that the
mapping is the direct C one.

These _c routines closely match the OpenGL C API but
it requires that the perl user hand manage the allocation,
initialization, packing and unpacking, etc for each
function call.

Please see this source file for the implementations of

  glGetShaderInfoLog_p
  glGetProgramInfoLog_p
  glGetVersion_p

  croak_on_gl_error

showing the use of some utility routines to interface
to the OpenGL API routines.  OpenGL::Modern::Helpers
will be kept up to date with each release to document
the API implementations and usage as the bindings
evolve and improve.  Once standardized and stable,
a final version of Helpers.pm will be released.

=cut

our @EXPORT_OK = qw(
  pack_GLuint
  pack_GLfloat
  pack_GLdouble
  pack_GLint
  pack_GLstrings
  pack_ptr
  iv_ptr
  xs_buffer

  glGetShaderInfoLog_p
  glGetProgramInfoLog_p
  croak_on_gl_error

  glGetVersion_p
  glGenTextures_p
  glGetProgramiv_p
  glGetShaderiv_p
  glShaderSource_p
  glGenFramebuffers_p
  glGenVertexArrays_p
  glGenBuffers_p
  glGetIntegerv_p
  glBufferData_p
  glUniform2f_p
  glUniform4f_p
);

our $PACK_TYPE = $Config{ptrsize} == 4 ? 'L' : 'Q';

sub pack_GLuint { pack 'I*', @_ }
sub pack_GLint { pack 'i*', @_ }
sub pack_GLfloat { pack 'f*', @_ }
sub pack_GLdouble { pack 'd*', @_ }
sub pack_GLstrings { pack 'P*', @_ } # No declare params as don't want copies

# No parameter declaration because we don't want copies
# This returns a packed string representation of the
# pointer to the perl string data.  Not useful as is
# because the scope of the inputs is not maintained so
# the PV data may disappear before the pointer is actually
# accessed by OpenGL routines.
#
sub pack_ptr {
    $_[0] = "\0" x $_[1];
    return pack 'P', $_[0];
}

sub iv_ptr {
    $_[0] = "\0" x $_[1] if $_[1];
    return unpack( $PACK_TYPE, pack( 'P', $_[0] ) );
}

# No parameter declaration because we don't want copies
# This makes a packed string buffer of desired length.
# As above, be careful of the variable scopes.
#
sub xs_buffer {
    $_[0] = "\0" x $_[1];
    $_[0];
}

# This should probably be named glpGetVersion since there is actually
# no glGetVersion() in the OpenGL API.
#
sub glGetVersion_p {

    # const GLubyte * GLAPIENTRY glGetString (GLenum name);
    my $glVersion = glGetString( GL_VERSION );
    ( $glVersion ) = ( $glVersion =~ m!^(\d+\.\d+)!g );
    $glVersion;
}

*croak_on_gl_error = \&glpCheckErrors;

sub glBufferData_p {                                        # NOTE: this might be better named glpBufferDataf_p
    my $usage = pop;
    my ( $target, $size, @data ) = @_;
    my $pdata = pack "f*", @data;

    glBufferData_c $target, $size, unpack( $PACK_TYPE, pack( 'p', $pdata ) ), $usage;
}

sub glBufferData_o {                                        # NOTE: this was glBufferData_p in OpenGL
    my ( $target, $oga, $usage ) = @_;
    glBufferData_c $target, $oga->length, $oga->ptr, $usage;
}

sub glUniform2fv_p {                                        # NOTE: this name is more consistent with OpenGL API
    my ( $uniform, $v0, $v1 ) = @_;
    glUniform2f $uniform, $v0, $v1;
}

sub glUniform4fv_p {                                        # NOTE: this name is more consistent with OpenGL API
    my ( $uniform, $v0, $v1, $v2, $v3 ) = @_;
    glUniform4f $uniform, $v0, $v1, $v2, $v3;
}

1;
