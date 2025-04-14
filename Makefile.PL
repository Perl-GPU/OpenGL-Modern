use strict;
use ExtUtils::MakeMaker;
use Devel::CheckLib 'assert_lib';

my $include = "-I. -Iinclude";
my $libs;
my $define = "-DGLEW_NO_GLU -DGLEW_STATIC";
my $DYNS;
if ( $^O eq 'MSWin32' ) {
  $libs   = '-lopengl32 -lgdi32 -lmsimg32';
  $define .= " -D_WIN32",
} elsif ( $^O eq 'cygwin' ) {
  $libs = '-lGL -lX11';
} elsif ( $^O eq 'darwin' ) {
  $DYNS = { 'OTHERLDFLAGS' => '-framework OpenGL' };
  $define .= " -Wno-compound-token-split-by-macro -DGL_SILENCE_DEPRECATION";
} else {
  $libs = '-lGL -lX11';
}
my %buildargs = (
  LIBS             => $libs,
  DEFINE           => $define,
  INC              => $include,
  $DYNS ? ( dynamic_lib => $DYNS ) : (),
);
die "$@\nOS unsupported\n" if !eval { assert_lib %buildargs; 1 };
WriteConfigPM({ LIBS => $libs || $DYNS->{OTHERLDFLAGS} });

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
    'Modern.c' => 'auto-xs.inc',
    'Modern$(OBJ_EXT)' => 'glew.c glew-context.c include/GL/glew.h include/GL/wglew.h const.h',
  },
  clean => { FILES => 'auto-xs.inc const.h lib/OpenGL/Modern/Config.pm' },
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

sub WriteConfigPM {
  my($config) = @_;
  die "Unable to write to Config.pm\n" if !open my $fh, ">", "lib/OpenGL/Modern/Config.pm";
  print $fh q{# This is the Perl OpenGL build configuration file.
# It contains the final OpenGL build arguments from
# the configuration process.  Access the values by
# use OpenGL::Modern::Config which defines the variable
# $OpenGL::Modern::Config containing the hash arguments needed for
# WriteMakefile()
};
  require Data::Dumper;
  { no warnings; $Data::Dumper::Sortkeys = 1; } # deterministic output
  print $fh Data::Dumper->Dump( [$config], [qw(OpenGL::Modern::Config)] );
  print $fh qq{1;\n};
}
