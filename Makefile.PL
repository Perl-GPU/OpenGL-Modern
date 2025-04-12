use strict;
use ExtUtils::MakeMaker;
use lib 'lib';
use OpenGL::Modern::NameLists::MakefileAll;
use ExtUtils::Constant ();
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
    'Modern.c' => 'Modern.xs auto-xs.inc src/glew.c include/GL/glew.h include/GL/wglew.h',
  },
  clean => { FILES => 'auto-xs.inc const-c.inc const-xs.inc' },
  %buildargs,
);

# If you edit these definitions to change the constants used by this module,
# you will need to use the generated const-c.inc and const-xs.inc
# files to replace their "fallback" counterparts before distributing your
# changes.
my @names = OpenGL::Modern::NameLists::MakefileAll::makefile_all();

ExtUtils::Constant::WriteConstants(
    NAME         => 'OpenGL::Modern',
    NAMES        => \@names,
    DEFAULT_TYPE => 'UV',
    C_FILE       => 'const-c.inc',
    XS_FILE      => 'const-xs.inc',
);

sub MY::postamble {
  my $deps = join ' ', 'utils/generate-XS.pl', glob 'include/GL/*.h';
  <<EOF;
lib/OpenGL/Modern/NameLists/Modern.pm auto-xs.inc : $deps
\t\$(PERLRUN) utils/generate-XS.pl
EOF
}
