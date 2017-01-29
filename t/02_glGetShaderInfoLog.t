#!perl -w
use strict;
use Test::More tests => 2;
use OpenGL::Modern ':all';

glewCreateContext();
glewInit();

# Set up a windowless OpenGL context?!
my $id = glCreateShader(GL_VERTEX_SHADER);
diag "Got vertex shader $id, setting source";

my $shader = <<SHADER;
int i;
provoke a syntax error
SHADER

glShaderSource_p($id, $shader);

glCompileShader($id);
    
warn "Looking for errors";
my $ok = "\0" x 4;
glGetShaderiv_c($id, GL_COMPILE_STATUS, unpack('Q',pack('p',$ok)));
$ok = unpack 'I', $ok;
if( $ok == GL_FALSE ) {
    pass "We recognize an invalid shader as invalid";

    my $bufsize = 1024*64;
    my $len = "\0" x 4;
    my $buffer = "\0" x $bufsize;
    glGetShaderInfoLog_c( $id, $bufsize, unpack('Q',pack('p',$len)), $buffer);
    $len = unpack 'I', $len;
    my $log = substr $buffer, 0, $len;
    isnt $log, '', "We get some error message";
      
    diag "Error message: $log";
      
} else {
    fail "We recognize an invalid shader as valid";

};

done_testing;
