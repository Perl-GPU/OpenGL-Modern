use strictures;
use IO::All -binary;
use Text::CSV_XS 1.27 qw( csv );
use Devel::Confess;
use FindBin '$Bin';

run();

sub run {
    my $target_dir = "$Bin/pointer_functions_by_feature";
    mkdir $target_dir if not -d $target_dir;
    my %features;
    push @{ $features{ $_->{feature} } }, $_ for eval io( "$Bin/badp-XS-sigs-numptr.pl" )->all;
    my $sigpars = Signature::Parser->new;
    for my $feature ( sort keys %features ) {
        my @functions = @{ $features{$feature} };
        my $files     = 1;
        my $pointers  = 0;
        my @arguments;
        my @funcs_to_do = sort { $a->{name} cmp $b->{name} } @functions;
        for my $i ( 0 .. $#funcs_to_do ) {
            my $function  = $funcs_to_do[$i];
            my @sig_parts = @{ $sigpars->from_string( $function->{restype} . " res, " . $function->{signature} ) };
            $sig_parts[0]{name} = undef;
            $sig_parts[$_]{pos} = $_ - 1 for 0 .. $#sig_parts;
            add_raw_line( \@arguments, $function->{name}, $_ ) for @sig_parts;
            $pointers += $function->{nptr};

            # try to batch things by dumping after 10 pointers (except for the very last loop)
            next if $i == $#funcs_to_do or $pointers <= 10;
            dump_arguments( $feature, \@arguments, \$files, \$pointers, $target_dir );
        }
        $files = 0 if $files == 1;    # don't add series numbers to filename if there's only one file
        dump_arguments( $feature, \@arguments, \$files, \$pointers, $target_dir ) if @arguments;
    }
    return;
}

sub add_raw_line {
    my ( $arguments, $function, $part ) = @_;
    my $array_size = $part->{array_size} || $part->{pointer_depth} ? "???" : "N/A";
    my $inout = $part->{pos} == -1 ? "out" : $part->{pointer_depth} ? "???" : "in";
    my $width = $part->{pointer_depth} ? "???" : "fixed";
    my $notes = ( $part->{pos} == -1 and $part->{type} eq "void" ) ? "N/A" : $part->{pointer_depth} ? "???" : "??";
    push @{$arguments}, [
        map defined() ? $_ : "N/A",    #
        $function, @{$part}{qw( pos pointer_depth type name )}, $array_size, $inout, $width, $notes
    ];
    return;
}

sub dump_arguments {
    my ( $feature, $arguments, $files, $pointers, $target_dir ) = @_;
    my $file_number = ${$files} ? sprintf( ".%04d", ${$files} ) : "";
    my $target      = "$target_dir/$feature$file_number.csv";
    my @header      = qw( func_name arg_pos pointer_depth type arg_name array_size inout width notes );
    csv( in => [ \@header, @{$arguments} ], out => $target, auto_diag => 9 );
    ${$pointers}  = 0;
    @{$arguments} = ();
    ${$files}++;
    return;
}

package Signature::Parser;

use parent 'Parser::MGC';
use curry;

sub parse {
    my ( $self ) = @_;

    my @type_words = (
        qw( const void ),
        map "GL$_", qw( void boolean enum short ushort byte ubyte
          sizei sizeiptr sizeiptrARB
          float double half char bitfield fixed
          DEBUGPROC DEBUGPROCAMD DEBUGPROCARB handleARB charARB sync clampd clampf
          vdpauSurfaceNV VULKANPROCNV
          ),
        qw( int uint intptr intptrARB int64 int64EXT uint64 uint64EXT )    # how many fucking ints do you need, GL
    );

    return $self->list_of(
        ",",
        sub {
            my $type_parts = $self->any_of(
                $self->curry::token_kw( qw( GLsync ) ),                    # there's one instance of GLsync GLsync
                $self->curry::sequence_of(
                    sub {
                        $self->any_of(
                            $self->curry::token_kw( @type_words ),         #
                            $self->curry::expect( "*" ),
                        );
                    }
                ),
            );
            $type_parts = [$type_parts] if not ref $type_parts;
            my $pointer_depth = 0;
            $pointer_depth += $_ =~ /\*/ for @{$type_parts};
            my $type = join " ", @{$type_parts};
            my $name = $self->token_ident;
            my $size =                                                     # halcy says [16] can be a mat4
              $self->maybe( $self->curry::scope_of( "[", $self->curry::token_number, "]" ) );
            $size = "INF" if not $size and $self->maybe( $self->curry::expect( "[]" ) );
            return { type => $type, name => $name, pointer_depth => $pointer_depth, array_size => $size };
        }
    );
}
