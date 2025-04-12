use strict;
use ExtUtils::MakeMaker;
use Devel::CheckLib 'assert_lib';

my $include = "-I. -Iinclude -Isrc";
my $libs;
my $define = "-DGLEW_NO_GLU";
my $DYNS;
if ( $^O eq 'MSWin32' ) {
  $libs   = '-lopengl32 -lgdi32 -lmsimg32';
  $define .= " -D_WIN32",
} elsif ( $^O eq 'cygwin' ) {
  $libs = '-lGL -lX11';
} elsif ( $^O eq 'darwin' ) {
  $DYNS = { 'OTHERLDFLAGS' => '-framework OpenGL' };
} else {
  $libs = '-lGL -lX11';
}
my %buildargs = (
  LIBS             => $libs,
  DEFINE           => $define,
  INC              => $include,
  $DYNS ? ( dynamic_lib => $DYNS ) : (),
);
die "$@\nOS unsupported\n" if not eval { assert_lib %buildargs; 1 };

WriteMakefile(
  NAME => 'OpenGL::Modern',
  VERSION_FROM => 'lib/OpenGL/Modern.pm',
  ABSTRACT_FROM => 'lib/OpenGL/Modern.pm',
  AUTHOR => 'Chris Marshall <chm@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {
  },
  CONFIGURE_REQUIRES => {
    'ExtUtils::MakeMaker' => '7.72',
    'Devel::CheckLib' => 0,
  },
  TEST_REQUIRES => {
    'Capture::Tiny' => 0,
    'Test::More' => '0.88',
  },
  META_MERGE => {
    "meta-spec" => { version => 2 },
    dynamic_config => 0,
    resources => {
      bugtracker  => {web=>'https://github.com/Perl-GPU/OpenGL-Modern/issues'},
      repository => {
        web  => 'https://github.com/Perl-GPU/OpenGL-Modern',
        url  => 'https://github.com/Perl-GPU/OpenGL-Modern.git',
        type => 'git',
      },
      x_IRC => 'irc://irc.perl.org/#pogl',
    },
  },
  MIN_PERL_VERSION => '5.016',
  XSPROTOARG       => '-noprototypes',
  depend           => {
    'Modern.c' => 'Modern.xs auto-xs.inc src/glew.c include/GL/glew.h include/GL/wglew.h const.h',
  },
  clean => { FILES => 'auto-xs.inc const.h' },
  %buildargs,
);

sub MY::postamble {
  my ($self) = @_;
  my $deps = join ' ', 'utils/generate-XS.pl', glob 'include/GL/*.h';
  my $const_cmd = $self->oneliner(
    'print " OGL_CONST_i($_)\n" for makefile_all();',
    [qw(-Ilib -MOpenGL::Modern::NameLists::MakefileAll)],
  );
  <<EOF;
lib/OpenGL/Modern/NameLists/Modern.pm auto-xs.inc : $deps
\t\$(PERLRUN) utils/generate-XS.pl

const.h : lib/OpenGL/Modern/NameLists/MakefileAll.pm
\t$const_cmd >\$@
EOF
}
