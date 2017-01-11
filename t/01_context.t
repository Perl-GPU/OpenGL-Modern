#! /usr/bin/perl

use strict;
use warnings;
use Test::More;
use OpenGL::Modern ':all';

#eval 'use Test::Pod::Coverage';
#my $xerror = Prima::XOpenDisplay;
#plan skip_all => $xerror if defined $xerror;

my $tests = 1;
plan tests => $tests;

glewCreateContext();
glewInit();

my $opengl_version = glGetString(GL_VERSION);
isn't '', $opengl_version;

note "We got OpenGL version $opengl_version";
