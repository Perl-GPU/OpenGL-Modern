requires 'Carp' => 0;
requires 'Import::Into' => 0;

on configure => sub {
    requires 'Capture::Tiny'                 => 0;
    requires 'ExtUtils::MakeMaker'           => '7.72';
    requires 'ExtUtils::MakeMaker::CPANfile' => 0;
    requires 'Devel::CheckLib'               => 0;
};

on test => sub {
    requires 'Test::More'      => '0.88';
};
