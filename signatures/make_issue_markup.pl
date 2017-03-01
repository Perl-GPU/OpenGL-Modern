use strictures;
use IO::All -binary;
use Text::CSV_XS qw( csv );
use Devel::Confess;
use FindBin '$Bin';

run();

sub run {
    my $target_dir = "$Bin/pointer_functions_by_feature";
    my @files      = io( $target_dir )->all_files;
    for my $file ( @files ) {
        my @args = @{csv( in => $file, auto_diag => 9 )};
        shift @args;
        my %functions = map {$_->[0], 1} @args;
        my @functions = sort keys %functions;
        print "  * **".($file->filename)."** : @functions\n    - [ ] started\n    - [ ] done\n";
    }
}
