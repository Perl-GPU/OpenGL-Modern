use strict;
use warnings;

my %type2func = (
  GLboolean => ['IV'],
  GLubyte => ['UV'],
  GLbyte => ['IV'],
  GLfixed => ['IV'],
  GLshort => ['IV'],
  GLushort => ['UV'],
  GLuint => ['UV'],
  GLint => ['IV'],
  GLuint64 => ['UV'],
  GLuint64EXT => ['UV'],
  GLint64 => ['IV'],
  GLint64EXT => ['IV'],
  GLhalf => ['NV'], # not right
  GLfloat => ['NV'],
  GLdouble => ['NV'],
  GLclampd => ['NV'],
  'GLchar*' => ['PV_nolen'],
  GLenum => ['IV'],
);
sub typefunc {
  my ($type) = @_;
  $type2func{$type};
}

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

sub make_aliases {
  my ($aliases) = @_;
  my $i = 0;
  !@$aliases ? "" : "ALIAS:\n".join '', map "  $_ = ".++$i."\n", @$aliases;
}

sub parse_ptr {
  my ($data) = @_;
  my $const = (my $type = $data->[1]) =~ s#\bconst\b##g;
  $type =~ s#\*##;
  $type =~ s#\s##g;
  [$type, $const];
}

sub bindings {
  die "list context only" if !wantarray;
  my ($name, $s, $counts) = @_;
  my $avail_check = ($s->{glewtype} eq 'fun' && $s->{glewImpl})
    ? "  OGLM_AVAIL_CHECK($s->{glewImpl}, $name)\n"
    : "";
  my @argdata = @{$s->{argdata} || []};
  my $callarg_list = $s->{glewtype} eq 'var' ? "" : "(@{[ join ', ', map $_->[0], @argdata ]})";
  my $thistype = $s->{restype};
  my @ptr_arg_inds = @{$s->{ptr_args} || []};
  my $c_suffix = @ptr_arg_inds ? '_c' : '';
  my %default = (
    binding_name => $name . $c_suffix,
    xs_rettype => $s->{restype},
    xs_args => join(', ', map $_->[0], @argdata),
    xs_argdecls => join('', map "  $_->[1]$_->[0];\n", @argdata),
    aliases => [ map "$_$c_suffix", sort keys %{ $s->{aliases} || {} } ],
    xs_code => "CODE:\n",
    error_check => ($name eq "glGetError") ? "" : "OGLM_CHECK_ERR($name, )",
    avail_check => $avail_check,
    beforecall => '',
    retcap => ($thistype eq 'void' ? '' : 'RETVAL = '),
    callarg_list => $callarg_list,
    error_check2 => ($name eq "glGetError") ? "" : "OGLM_CHECK_ERR($name, )",
    aftercall => '',
    retout => ($thistype eq 'void' ? '' : "\nOUTPUT:\n  RETVAL"),
  );
  my @ret = \%default;
  my %dynlang = %{ $s->{dynlang} || {} };
  return @ret if !@ptr_arg_inds or !%dynlang;
  my %pbinding = (%default, binding_name => $name . '_p',
    aliases => [ map "${_}_p", sort keys %{ $s->{aliases} || {} } ],
  );
  @ptr_arg_inds = grep $_ >= 0, @ptr_arg_inds;
  my %name2data = map +($_->[0] => $_), @argdata;
  my %name2parsed = map +($_->[0] => parse_ptr($_)), @argdata[@ptr_arg_inds];
  die "$name: undefined dynlang arg '$_'" for grep /^[a-z]/ && !exists $name2data{$_}, keys %dynlang;
  my %this = %pbinding;
  die "$name: cannot have both RETVAL and OUTPUT" if $dynlang{OUTPUT} and $dynlang{RETVAL};
  if (my $retval = delete $dynlang{RETVAL}) {
    die "$name: dynlang RETVAL '$retval' not arg to function" if !defined $name2data{$retval};
    $this{xs_rettype} = delete $dynlang{RETTYPE} // $name2data{$retval}[1];
    $this{aftercall} = "\n  RETVAL = $retval;";
    $this{retout} = "\nOUTPUT:\n  RETVAL";
  } elsif (my $output = delete $dynlang{OUTPUT}) {
    $this{aftercall} = "\n  $output";
    $this{xs_code} = "PPCODE:\n";
  }
  my @xs_inargs = grep !exists $dynlang{$_->[0]} && (!exists $name2parsed{$_->[0]} || $name2parsed{$_->[0]}[1]), @argdata;
  my $dotdotdot = grep /\bitems\b/, values %dynlang;
  $this{xs_args} = join(', ', (map $_->[0], @xs_inargs), $dotdotdot ? '...' : ());
  $this{xs_argdecls} = join('', map "  $_->[1]$_->[0];\n", @xs_inargs);
  my $beforecall = '';
  my $cleanup = delete $dynlang{CLEANUP} // '';
  $this{aftercall} .= "\n  $cleanup" if $cleanup;
  for my $get (sort grep $dynlang{$_} =~ /^</, keys %dynlang) {
    my $val = delete $dynlang{$get};
    $val =~ s#^<##;
    my ($getfunc) = $val =~ /^(\w+)/;
    $val =~ s#&(?![\{\(a-z])#&$get#;
    my $vardata = $name2data{$get};
    $beforecall .= "  $vardata->[1]$get;\n  $val;\n";
    $this{error_check} .= "\n  " if $this{error_check};
    $this{error_check} .= "OGLM_CHECK_ERR($getfunc, $cleanup)",
  }
  $this{error_check2} &&= "OGLM_CHECK_ERR($name, $cleanup)";
  for my $arr (sort grep !$dynlang{$_} && !$name2parsed{$_}[1], keys %name2parsed) {
    my $len = $name2data{$arr}[2] // die "$name: pointer arg without len";
    my $type = $name2parsed{$arr}[0];
    $type = 'char' if $type eq 'void';
    $beforecall .= "  $type $arr\[$len];\n";
  }
  my $need_cast;
  for my $var (sort keys %dynlang) {
    my $val = delete $dynlang{$var};
    die "$name: no arg data found for '$var'" unless my $data = $name2data{$var};
    my $type = $data->[1];
    $need_cast = $type =~ s#\bconst\b##g;
    $beforecall .= "  $type $var = $val;\n";
  }
  if ($need_cast) {
    $this{callarg_list} = $s->{glewtype} eq 'var' ? "" : "(@{[ join ', ', map qq{($_->[1])$_->[0]}, @argdata ]})";
  }
  $this{beforecall} = $beforecall;
  push @ret, \%this;
  @ret;
}

sub assemble_enum_groups {
  my ($groups, $counts, %g2c2s) = @_;
  for my $g (keys %$groups) {
    my (@syms, %c2s) = @{ $groups->{$g} };
    for (@syms) {
      next if !defined(my $c = $counts->{$_});
      push @{ $c2s{$c} }, $_;
    }
    $g2c2s{$g} = \%c2s if keys %c2s;
  }
  \%g2c2s;
}

1;
