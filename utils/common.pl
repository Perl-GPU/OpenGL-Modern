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
  my ($aliases, $suffix) = @_;
  my $i = 0;
  !$aliases ? "" : "ALIAS:\n".join '',
    map "  $_$suffix = ".++$i."\n", sort keys %$aliases;
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
    aliases => make_aliases($s->{aliases}, $c_suffix),
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
  return @ret if !@ptr_arg_inds;
  my %pbinding = (%default, binding_name => $name . '_p',
    aliases => make_aliases($s->{aliases}, '_p'),
  );
  @ptr_arg_inds = grep $_ >= 0, @ptr_arg_inds;
  my %name2data = map +($_->[0] => $_), @argdata;
  my @ptr_args = @argdata[@ptr_arg_inds];
  my %dynlang = %{ $s->{dynlang} || {} };
  my $compsize_from = ($ptr_args[0][2]//'') =~ /COMPSIZE\(([^,]+)\)/ ? $1 : undef;
  my $compsize_data = $compsize_from && $name2data{$compsize_from};
  my $compsize_group = $compsize_data && $compsize_data->[3];
  if ($name =~ /^gl(?:Gen|Create)/ && @argdata == 2 && $s->{restype} eq 'void') {
    push @ret, {
      %pbinding,
      xs_args => join(', ', map $_->[0], $argdata[0]),
      xs_argdecls => join('', map "  $_->[1]$_->[0];\n", $argdata[0]),
      xs_code => "PPCODE:\n",
      beforecall => "  OGLM_GEN_SETUP($name, $argdata[0][0], $argdata[1][0])\n",
      error_check2 => "OGLM_CHECK_ERR($name, free($argdata[1][0]))",
      aftercall => "\n  OGLM_GEN_FINISH($argdata[0][0], $argdata[1][0])",
    };
  } elsif ($name =~ /^gl(?:Get)/ && @ptr_args == 1 && $compsize_group && $counts->{$compsize_group}) {
    my ($datatype) = $ptr_args[0][1] =~ /^(?:const\s*)?(\w+)/;
    my $typefunc = typefunc($datatype) or die "No typefunc for '$datatype'";
    $typefunc = "newSV" . lc $typefunc->[0];
    my $not_that = $ptr_args[0][0];
    my @filtered_args = grep $_->[0] ne $not_that, @argdata;
    push @ret, {
      %pbinding,
      xs_args => join(', ', map $_->[0], @filtered_args),
      xs_argdecls => join('', map "  $_->[1]$_->[0];\n", @filtered_args),
      xs_code => "PPCODE:\n",
      beforecall => "  OGLM_GET_SETUP($name, $compsize_group, $compsize_from, $datatype, $ptr_args[0][0])\n",
      error_check2 => "OGLM_CHECK_ERR($name, )",
      aftercall => "\n  OGLM_GET_FINISH($compsize_from, $typefunc, $ptr_args[0][0])",
    };
  } elsif (%dynlang) {
    my %this = %pbinding;
    my $retval = delete $dynlang{RETVAL};
    if ($retval) {
      $this{xs_rettype} = $name2data{$retval}[1];
      $this{aftercall} = "\n  RETVAL = $retval;";
      $this{retout} = "\nOUTPUT:\n  RETVAL";
    }
    my @thisargs = grep !exists $dynlang{$_->[0]}, @argdata;
    my $dotdotdot = grep /\bitems\b/, values %dynlang;
    $this{xs_args} = join(', ', (map $_->[0], @thisargs), $dotdotdot ? '...' : ());
    $this{xs_argdecls} = join('', map "  $_->[1]$_->[0];\n", @thisargs);
    my $beforecall = '';
    my $cleanup = delete $dynlang{CLEANUP} // '';
    $this{aftercall} .= "\n  $cleanup" if $cleanup;
    for my $get (sort grep $dynlang{$_} =~ /^</, keys %dynlang) {
      my $val = delete $dynlang{$get};
      $val =~ s#^<##;
      my ($getfunc) = $val =~ /^(\w+)/;
      $val =~ s#&#&$get#;
      my $vardata = $name2data{$get};
      $beforecall .= "  $vardata->[1]$get;\n  $val;\n";
      $this{error_check} .= "\n  " if $this{error_check};
      $this{error_check} .= "OGLM_CHECK_ERR($getfunc, $cleanup)",
    }
    $this{error_check2} &&= "OGLM_CHECK_ERR($name, $cleanup)";
    for my $arr (sort grep $dynlang{$_} =~ /^\[/, keys %dynlang) {
      my $val = delete $dynlang{$arr};
      my $vardata = $name2data{$arr};
      (my $type = $vardata->[1]) =~ s#\*##;
      $beforecall .= "  $type $arr$val;\n";
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
  }
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
