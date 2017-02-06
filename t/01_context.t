#! /usr/bin/perl

use strict;
use warnings;
use Test::More;
use OpenGL::Modern ':all';

#eval 'use Test::Pod::Coverage';
#my $xerror = Prima::XOpenDisplay;
#plan skip_all => $xerror if defined $xerror;

my $tests = 3;
plan tests => $tests;

TODO: {
    local $TODO = "Maybe should skip some if the first 1 or 2 fail";

    ok(my $gCC_status = glewCreateContext(), "glewCreateContext");  # returns GL_TRUE or GL_FALSE
    print "glewCreateContext returned '$gCC_status'\n";

    ok(my $gI_status = glewInit(), "glewInit");    # returns GLEW_OK or ???
    print "glewInit returned '$gI_status'\n";

    my $opengl_version = glGetString(GL_VERSION);  # should skip if no context (and/or no init?)
    isnt '', $opengl_version;

    diag "We got OpenGL version $opengl_version";
}
