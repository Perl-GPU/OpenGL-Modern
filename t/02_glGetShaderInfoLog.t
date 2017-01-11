#!perl -w
use strict;
use Test::More tests => 2;
use OpenGL::Modern ':all';

glewCreateContext();
glewInit();

# Set up a windowless OpenGL context?!
my $id = glCreateShader(GL_VERTEX_SHADER);
note "Got vertex shader $id, setting source";

my $shader = <<SHADER;
int i;
provoke a syntax error
SHADER

my $shader_length = length($shader);
glShaderSource($id, 1, pack('P',$shader), pack('I',$shader_length));

glCompileShader($id);
    
note "Looking for errors";
glGetShaderiv($id, GL_COMPILE_STATUS, (my $ok = "\0" x 8));
$ok = unpack 'I', $ok;
if( $ok == GL_FALSE ) {
    pass "We recognize an invalid shader as invalid";

    my $bufsize = 1024*64;
    glGetShaderInfoLog( $id, $bufsize, (my $len = "\0" x 8), (my $buffer = "\0" x $bufsize));
    $len = unpack 'I', $len;
    my $log = substr $buffer, 0, $len;
    isnt $log, '', "We get some error message";
      
    note "Error message: $log";
      
} else {
    fail "We recognize an invalid shader as valid";
};

done_testing;
