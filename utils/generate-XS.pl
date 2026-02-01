use strict;
use warnings;
use OpenGL::Modern::Registry;
require './utils/common.pl';

=head1 PURPOSE

This script reads the function signatures from the registry
and creates XS stubs for each.

=cut

our %signature;
*signature = \%OpenGL::Modern::Registry::registry;
our %groups;
*groups = \%OpenGL::Modern::Registry::groups;

my $g2c2s = assemble_enum_groups(\%groups, \%OpenGL::Modern::Registry::counts);
sub generate_glew_xs {
  my $content;
  for my $name (@_) {
    my $item = $signature{$name};
    for my $s (bindings($name, $item, $g2c2s, \%signature)) {
      die "Error generating for $name: no return type" if !$s->{xs_rettype};
      my $res = "$s->{xs_rettype}\n$s->{binding_name}($s->{xs_args})\n";
      $res .= $s->{xs_argdecls};
      $res .= make_aliases($s->{aliases})."$s->{xs_code}  OGLM_GLEWINIT\n";
      $res .= "  $s->{error_check}\n" if $s->{error_check};
      $res .= $s->{avail_check} . $s->{beforecall};
      $res .= "  $s->{retcap}$name$s->{callarg_list};";
      $res .= "\n  $s->{error_check2}" if $s->{error_check2};
      $content .= "$res$s->{aftercall}$s->{retout}\n\n";
    }
  }
  $content;
}

my $xs_code = generate_glew_xs(sort grep $signature{$_}{glewtype} eq 'fun', keys %signature);
save_file('auto-xs.inc', $xs_code);
my $var_code = generate_glew_xs(sort grep $signature{$_}{glewtype} eq 'var', keys %signature);
save_file('auto-xs-var.inc', $var_code);

our %enums;
*enums = \%OpenGL::Modern::Registry::enums;
my %known_constant = map +($_=>1), @OpenGL::Modern::Registry::glconstants;
my $enums_code = <<'EOF';
char *
enum2name(g, e)
  char *g;
  GLenum e;
CODE:
  RETVAL = NULL;
EOF
for my $g (sort keys %groups) {
  next if $g eq 'SpecialNumbers';
  next unless my @names = grep $known_constant{$_}, @{ $groups{$g} };
  $enums_code .= <<"EOF";
  if (!strcmp(g, "$g")) {
    switch (e) {
EOF
  my %val2names; push @{ $val2names{$enums{$_}} }, $_ for @names;
  my @final_names;
  for my $val (keys %val2names) {
    my @names = @{ $val2names{$val} };
    push @final_names, (sort { length($a) <=> length($b) } @names)[0];
  }
  $enums_code .= <<"EOF" for sort @final_names;
      case $_: RETVAL = "$_"; break;
EOF
  $enums_code .= <<"EOF";
      default: RETVAL = "UNKNOWN ENUM";
    }
    goto alldone;
  }
EOF
}
$enums_code .= <<'EOF';
  if (!RETVAL) RETVAL = "UNKNOWN GROUP";
  alldone:
OUTPUT:
  RETVAL
EOF
save_file('auto-xs-enums.inc', $enums_code);
