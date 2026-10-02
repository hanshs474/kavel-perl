use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'WebService::Kavel',
    AUTHOR           => 'Kavel <support@kavel.ai>',
    VERSION_FROM     => 'lib/WebService/Kavel.pm',
    ABSTRACT         => 'Generate AI images with no API key and no account',
    LICENSE          => 'mit',
    EXE_FILES        => ['bin/kavel'],
    MIN_PERL_VERSION => '5.014',
    PREREQ_PM        => { 'HTTP::Tiny' => '0.056', 'JSON::PP' => 0, 'IO::Socket::SSL' => '1.56', 'Net::SSLeay' => '1.49' },
    TEST_REQUIRES    => { 'Test::More' => 0 },
    META_MERGE       => {
        'meta-spec' => { version => 2 },
        resources   => {
            homepage   => 'https://www.kavel.ai',
            repository => { type => 'git', url => 'https://github.com/hanshs474/kavel-perl.git', web => 'https://github.com/hanshs474/kavel-perl' },
            bugtracker => { web => 'https://github.com/hanshs474/kavel-perl/issues' },
        },
    },
);
