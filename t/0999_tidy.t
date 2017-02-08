use strict;
use warnings;
use Test::InDistDir;
use Test::More 0.88;
use IO::All -binary;
use lib "t/lib";
use Devel::Confess;

SKIP: if ( !eval { require Capture::Tiny && require Perl::Tidy } ) {
    skip "test requires Capture::Tiny and Perl::Tidy", 1;
    exit;
}

SKIP: if ( $ENV{SKIP_TIDY_TESTS} ) {
    skip "test skipped due to \$ENV{SKIP_TIDY_TESTS}", 1;
    exit;
}

run();

sub run {
    note "set \$ENV{SKIP_TIDY_TESTS} to skip these";
    eval { report_untidied_files() };
    pass;
    done_testing;
}

sub report_untidied_files {
    require PerlTidyCheck;

    return unless    #
      my @untidied =
      PerlTidyCheck::find_untidied_files( sub { grep !/^signatures.*XS.*sig.*\.pl$|NameLists.*\.pm$/, @_ } );

    my $report = join "",    #
      "found untidied files:", "\n\n", map( PerlTidyCheck::format_untidied_entry( $_ ), @untidied ), "\n";
    diag $report;

    return;
}
