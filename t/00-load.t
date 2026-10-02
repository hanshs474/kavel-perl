use strict;
use warnings;
use Test::More tests => 3;
use_ok('WebService::Kavel');
my $k = WebService::Kavel->new;
is($k->generate('')->{reason}, 'other', 'empty prompt is refused locally');
is($k->edit('ftp://x', 'blue')->{reason}, 'other', 'non-http source is refused locally');
