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

    ok(glewCreateContext(), "glewContextCreate");
    ok(glewInit(), "glewInit");

    my $opengl_version = glGetString(GL_VERSION);
    isnt '', $opengl_version;

    diag "We got OpenGL version $opengl_version";
}
