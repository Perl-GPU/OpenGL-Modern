# maintained manually, based on output from EU:D
package OpenGL::Modern::Install::Files;
use strict;
use warnings;
require OpenGL::Modern::Config;

our $CORE = undef;
foreach (@INC) {
  if ( -f $_ . "/OpenGL/Modern/Install/Files.pm") {
    $CORE = $_ . "/OpenGL/Modern/Install/";
    last;
  }
}

our $self = {
  deps => [],
  inc => $OpenGL::Modern::Config->{INC},
  libs => $OpenGL::Modern::Config->{LIBS},
  typemaps => [$CORE."typemap"],
};

our @deps = @{ $self->{deps} };
our @typemaps = @{ $self->{typemaps} };
our $libs = $self->{libs};
our $inc = $self->{inc};

sub deps { @{ $self->{deps} }; }

sub Inline {
  my ($class, $lang) = @_;
  +{ map { (uc($_) => $self->{$_}) } qw(inc libs typemaps) };
}

1;
