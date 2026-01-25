#!perl -w
use strict;
use Config;
use Test::More tests => 2;
use OpenGL::Modern ':all';
use OpenGL::Modern::Helpers 'glGetVersion_p';

SKIP: {
    skip "glewInit not successful, skipping tests", 2 if glewCreateContext() or glewInit();    # GLEW_OK == 0
    skip "OpenGL 2 required at least for these tests", 2 if glGetVersion_p() < 2;

    # Set up a windowless OpenGL context?!
    my $id = glCreateShader( GL_VERTEX_SHADER );
    note "Got vertex shader $id, setting source";

    my $shader = <<SHADER;
int i;
provoke a syntax error
SHADER

    glShaderSource_p( $id, $shader );

    glCompileShader( $id );

    my $ok = glGetShaderiv_p( $id, GL_COMPILE_STATUS );
    if ( $ok == GL_FALSE ) {
        pass "We recognize an invalid shader as invalid";

        my $log = glGetShaderInfoLog_p( $id );
        isnt $log, '', "We get some error message";

        note "Error message: $log";

    }
    else {
        fail "We recognize an invalid shader as valid";

    }

}

done_testing;
