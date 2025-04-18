package OpenGL::Modern;

use strict;
use warnings;
use Carp;

use Exporter 'import';

use OpenGL::Modern::Registry;

our $VERSION    = '0.04_01';
our $XS_VERSION = $VERSION;
$VERSION = eval $VERSION;    # see L<perlmodstyle>

our @glFunctions = OpenGL::Modern::Registry::gl_functions();
our @glew_functions = qw(
  glewCreateContext
  glewGetErrorString
  glewIsSupported
  glewInit
  done_glewInit
);
our @glp_functions = qw(
  glpSetAutoCheckErrors
  glpCheckErrors
  glpErrorString
);
our %EXPORT_TAGS_GL = OpenGL::Modern::Registry::EXPORT_TAGS_GL();

our %EXPORT_TAGS = (
    %EXPORT_TAGS_GL,
    glewfunctions => \@glew_functions,
    glpfunctions => \@glp_functions,
    glconstants => \@OpenGL::Modern::Registry::glconstants,
    all => [
        @glFunctions,
        @glew_functions,
        @glp_functions,
        @OpenGL::Modern::Registry::glconstants,
    ]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

require XSLoader;
XSLoader::load( 'OpenGL::Modern', $XS_VERSION );

1;

__END__

=head1 NAME

OpenGL::Modern - Perl extension to Modern OpenGL API up to 4.5

=head1 SYNOPSIS

  use OpenGL::Modern qw(:all);
  use OpenGL qw(:glutfunctions :glutconstants);  # for GLUT

=head1 DESCRIPTION

C<OpenGL::Modern> provides perl bindings to the OpenGL
graphics APIs using the OpenGL Extension Wrangler (GLEW)
library.  These bindings were largely generated by parsing
the GLEW include file, C<glew.h>.

This module updates the original Perl OpenGL bindings
L<OpenGL> (often abbreviated as POGL) to include support
for all OpenGL API from 1.0 through 4.5.  The "modern"
OpenGL APIs are those starting with version 3.1 and higher.

OpenGL 3.1 was the first version where the legacy OpenGL
functionality from versions 1.x-3.0 was fully deprecated.
Much of the functionality that used to be accessed via the
extension mechanism in C<OpenGL> now is standardized and
in the OpenGL Core APIs.

=head2 OpenGL::Image

The module OpenGL::Image was written for the original OpenGL.pm, however it can
be made to work seamlessly with OpenGL::Modern. Where-as you previously loaded
it like this:

    use OpenGL::Image;             # loads OpenGL.pm on its own

You can prepend two use lines, and get this:

    use OpenGL::Array;             # not part of OpenGL::Modern
    use OpenGL::Modern::ImageHack; # sets up a fake OpenGL namespace
    use OpenGL::Image;             # now safe to do, won't load OpenGL.pm

=head2 EXPORT

None by default.

=head1 DEBUGGING

In development, you can call C<glpSetAutoCheckErrors(1)> which will have
each OpenGL function automatically call C<glGetErrors()> and report any
found. This is off by default for performance reasons.

=head1 SEE ALSO

OpenGL 4.x documentation at L<https://www.opengl.org/sdk/docs/man4/>

Perl OpenGL (POGL) and Perl OpenGL::Modern (POGL2) development
share common resources.  At some point C<OpenGL::Modern> will
replace the legacy C<OpenGL> implementation.  Together they are
referred to as POGL.

Perl OpenGL developer and users lists are at
L<https://sourceforge.net/p/pogl/mailman/?source=navbar>

Perl OpenGL IRC is at #pogl on irc.perl.org

POGL2 development will take place on github and the repository
is being set up there.  The sf.net repository will be the official
release repository and is mirrored from github.

=head1 AUTHOR

Chris Marshall, E<lt> devel dot chm dot 01 AT gmail dot com E<gt>

=head1 LICENSE and COPYRIGHT

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.22.0 or,
at your option, any later version of Perl 5 you may have available.

  Copyright (C) 2017 by Chris Marshall
  Copyright (C) 2016 by Max Maischein

=cut
