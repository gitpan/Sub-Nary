#!perl -T

use strict;
use warnings;

use Test::More tests => 40;

use Sub::Nary;

my $sn = Sub::Nary->new();

my ($x, $y, @a, %h);

my @tests = (
 [ sub { return },               0 ],
 [ sub { return () },            0 ],
 [ sub { return return },        0 ],
 [ sub { return do { return } }, 0 ],

 [ sub { return 1 },                           1 ],
 [ sub { return 1, 2 },                        2 ],
 [ sub { my $x = 1; $x = 2; return 3, 4, 5; }, 3 ],
 [ sub { do { 1; return 2, 3 } },              2 ],
 [ sub { do { 1; return 2, 3; 4 } },           2 ],
 [ sub { do { 1; return 2, return 3 } },       1 ],

 [ sub { return $x },     1 ],
 [ sub { return $x, $y }, 2 ],

 [ sub { return @a },                'list' ],
 [ sub { return $a[0] },             1 ],
 [ sub { return @a[1, 2] },          2 ],
 [ sub { return @a[2 .. 4] },        3 ],
 [ sub { return @a[do{ 1 .. 5 }] },  5 ],
 [ sub { return @a[do{ 1 .. $x }] }, 'list' ],

 [ sub { return %h },              'list' ],
 [ sub { return $h{a} },           1 ],
 [ sub { return @h{qw/a b/} },     2 ],
 [ sub { return @h{@a[1 .. 3]} },  3 ],
 [ sub { return @h{@a[$y .. 3]} }, 'list' ],

 [ sub { return $x, $a[3], $h{c} }, 3 ],
 [ sub { return $x, @a },           'list' ],
 [ sub { return %h, $y },           'list' ],

 [ sub { return 1 .. 3 }, 'list' ],

 [ sub { for (1, 2, 3) { return } },                                     0 ],
 [ sub { for (1, 2, 3) { } return 1, 2; },                               2 ],
 [ sub { for ($x, 1, $y) { return 1, 2 } },                              2 ],
 [ sub { for (@a) { return 1, do { $x } } },                             2 ],
 [ sub { for (keys %h) { return do { 1 }, do { return @a[0, 2] } } },    2 ],
 [ sub { for my $i (1 .. 4) { return @h{qw/a b/} } },                    2 ],
 [ sub { for (my $i; $i < 10; ++$i) { return 1, @a[do{return 2, 3}] } }, 2 ],
 [ sub { return 1, 2 for 1 .. 4 },                                       2 ],

 [ sub { while (1) { return } },            0 ],
 [ sub { while (1) { } return 1, 2 },       2 ],
 [ sub { while (1) { return 1, 2 } },       2 ],
 [ sub { while (1) { last; return 1, 2 } }, 2 ],
 [ sub { return 1, 2 while 1 },             2 ],
);

my $i = 1;
for (@tests) {
 my $r = $sn->nary($_->[0]);
 is_deeply($r, { $_->[1] => 1 }, 'return test ' . $i);
 ++$i;
}
