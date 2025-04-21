use strict;
use warnings;

# The functions where we specify manual implementations or prototypes
# These could also be read from Modern.xs, later maybe
my @manual_list = qw(
  glGetString
  glShaderSource_p
);

my %manual;
@manual{@manual_list} = ( 1 ) x @manual_list;

sub is_manual { $manual{$_[0]} }
sub manual_list { @manual_list }

sub slurp {
    my $filename = $_[0];
    open my $old_fh, '<:raw', $filename
      or die "Couldn't read '$filename': $!";
    join '', <$old_fh>;
}

sub save_file {
    my ( $filename, $new ) = @_;
    my $old = -e $filename ? slurp( $filename ) : "";
    if ( $new ne $old ) {
        print "Saving new version of $filename\n";
        open my $fh, '>:raw', $filename
          or die "Couldn't write new version of '$filename': $!";
        print $fh $new;
    }
}

sub bind_names {
  die "list context only" if !wantarray;
  my ($name, $s) = @_;
  return $name if !$s->{has_ptr_arg};
  return $name . '_c' if $name !~ /^glGen/ or @{$s->{argdata}} != 2;
  map "$name$_", qw(_c _p);
}

1;
