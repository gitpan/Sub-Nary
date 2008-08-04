#!perl -T

use strict;
use warnings;

use Test::More tests => 1;

use Sub::Nary;

my @scalops = Sub::Nary::scalops();
my $nbr     = Sub::Nary::scalops();

is($nbr, scalar @scalops, 'Sub::Nary::scalops return values in list/scalar context are consistent');
