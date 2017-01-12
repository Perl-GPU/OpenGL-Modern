#!perl -w
use strict;
use Test::More tests => 2;
use OpenGL::Modern ':all';
use OpenGL::Modern::Helpers 'xs_buffer';

glewCreateContext();
glewInit();

# Set up a windowless OpenGL context?!
my $id = glCreateShader(GL_VERTEX_SHADER);
diag "Got vertex shader $id, setting source";

my $shader = <<SHADER;
int i;
provoke a syntax error
SHADER

my $shader_length = length($shader);
glShaderSource($id, 1, pack('P',$shader), pack('I',$shader_length));

glCompileShader($id);
    
warn "Looking for errors";
glGetShaderiv($id, GL_COMPILE_STATUS, xs_buffer(my $ok, 8));
$ok = unpack 'I', $ok;
if( $ok == GL_FALSE ) {
    pass "We recognize an invalid shader as invalid";

    my $bufsize = 1024*64;
    glGetShaderInfoLog( $id, $bufsize, xs_buffer(my $len, 8), xs_buffer(my $buffer, $bufsize));
    $len = unpack 'I', $len;
    my $log = substr $buffer, 0, $len;
    isnt $log, '', "We get some error message";
      
    diag "Error message: $log";
      
} else {
    fail "We recognize an invalid shader as valid";
};

done_testing;
