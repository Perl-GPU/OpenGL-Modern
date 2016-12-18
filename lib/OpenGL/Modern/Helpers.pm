package # not an official package
OpenGL::Modern::Helpers;

BEGIN {
    # use Filter::signatures always
    $ENV{FORCE_FILTER_SIGNATURES} = 1;
}

use strict;
use Exporter 'import';
use Carp qw(croak);

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

use OpenGL::Modern qw(
    GL_NO_ERROR
    GL_INVALID_ENUM
    GL_INVALID_VALUE
    GL_INVALID_OPERATION
    GL_STACK_OVERFLOW
    GL_STACK_UNDERFLOW
    GL_OUT_OF_MEMORY
    GL_TABLE_TOO_LARGE
    GL_VERSION
    glGetString
    glGetError
    glGetShaderInfoLog
    glGetProgramInfoLog
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
conversion of input arguements from perl into the required
datatypes for the C OpenGL API, it then calls the OpenGL\
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

To simplify the initial XS implementation, all
pointer valued arguments in the OpenGL C API are
mapped to and from a perl PV which is a string
value that can be treated as a block of data.  

This simplifies the generation of the binding code
to the OpenGL C API but it requires that the perl
user hand manage the allocation, initialization,
packing and unpacking, etc for each function call.

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

use vars qw(@EXPORT_OK $VERSION %glErrorStrings);
$VERSION = '0.01';

@EXPORT_OK = qw(
    pack_GLuint
    pack_GLfloat
    pack_GLdouble
    pack_GLint
    pack_GLstrings
    pack_ptr
    xs_buffer
    
    glGetShaderInfoLog_p
    glGetProgramInfoLog_p
    croak_on_gl_error
        
    glGetVersion_p
);


%glErrorStrings = (
    GL_NO_ERROR() => 'No error has been recorded.',
    GL_INVALID_ENUM() => 'An unacceptable value is specified for an enumerated argument.',
    GL_INVALID_VALUE() => 'A numeric argument is out of range.',
    GL_INVALID_OPERATION() => 'The specified operation is not allowed in the current state.',
    GL_STACK_OVERFLOW() => 'This command would cause a stack overflow.',
    GL_STACK_UNDERFLOW() => 'This command would cause a stack underflow.',
    GL_OUT_OF_MEMORY() => 'There is not enough memory left to execute the command.',
    GL_TABLE_TOO_LARGE() => 'The specified table exceeds the implementation\'s maximum supported table size.',
);


sub pack_GLuint(@gluints) {
    pack 'I*', @gluints
}

sub pack_GLint(@gluints) {
    pack 'I*', @gluints
}

sub pack_GLfloat(@glfloats) {
    pack 'f*', @glfloats
}

sub pack_GLdouble(@gldoubles) {
    pack 'd*', @gldoubles
}

# No parameter declaration because we don't want copies
sub pack_GLstrings {
    pack 'P*', @_
}

# No parameter declaration because we don't want copies
sub pack_ptr {
    $_[0] = "\0" x $_[1];
    return pack 'P', $_[0];
}

# No parameter declaration because we don't want copies
sub xs_buffer {
    $_[0] = "\0" x $_[1];
    $_[0];
}

sub glGetShaderInfoLog_p( $shader ) {
    my $bufsize = 1024*64;
    # void glGetShaderInfoLog(GLuint shader, GLsizei bufSize, GLsizei* length, GLchar* infoLog);
    glGetShaderInfoLog( $shader, $bufsize, xs_buffer(my $len, 8), xs_buffer(my $buffer, $bufsize));
    $len = unpack 'I', $len;
    return substr $buffer, 0, $len;
}

sub glGetProgramInfoLog_p( $program ) {
    my $bufsize = 1024*64;
    # void glGetProgramInfoLog(GLuint program, GLsizei bufSize, GLsizei* length, GLchar* infoLog);
    glGetProgramInfoLog( $program, $bufsize, xs_buffer(my $len, 8), xs_buffer(my $buffer, $bufsize));
    $len = unpack 'I', $len;
    return substr $buffer, 0, $len;
}

sub glGetVersion_p() {
    # const GLubyte * GLAPIENTRY glGetString (GLenum name);
    my $glVersion = glGetString(GL_VERSION);
    ($glVersion) = ($glVersion =~ m!^(\d+\.\d+)!g);
    $glVersion
}

sub croak_on_gl_error() {
    # GLenum glGetError (void);
    my $error = glGetError();
    if( $error != GL_NO_ERROR ) {
        croak $glErrorStrings{ $error } || "Unknown OpenGL error: $error"
    };
}

1;
