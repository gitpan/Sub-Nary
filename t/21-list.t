#!perl -T

use strict;
use warnings;

use Test::More tests => 27;

use Sub::Nary;

my $sn = Sub::Nary->new();

my ($x, $y, @a, %h);

my @tests = (
 [ sub { },                   0 ],
 [ sub { () },                0 ],
 [ sub { (1, 2, 3)[2 .. 1] }, 0 ],

 [ sub { 1 },                               1 ],
 [ sub { 1, 2 },                            2 ],
 [ sub { my $x = 1; $x = 2; 3, 4, 5; },     3 ],
 [ sub { do { 1; 2, 3 } },                  2 ],
 [ sub { do { 1; 2, do { 3, do { 4 } } } }, 3 ],

 [ sub { $x },     1 ],
 [ sub { $x, $y }, 2 ],

 [ sub { @a },         'list' ],
 [ sub { $a[0] },      1 ],
 [ sub { @a[1, 2] },   2 ],
 [ sub { @a[2 .. 4] }, 3 ],

 [ sub { %h },          'list' ],
 [ sub { $h{a} },       1 ],
 [ sub { @h{qw/a b/} }, 2 ],

 [ sub { $x, $a[3], $h{c} }, 3 ],
 [ sub { $x, @a },           'list' ],
 [ sub { %h, $y },           'list' ],

 [ sub { 1 .. 3 },           'list' ],
 [ sub { my @a = (1 .. 4) }, 4 ],

 [ sub { (localtime)[0, 1, 2] }, 3 ],

 [ sub { for (1, 2, 3) { } },         0 ],
 [ sub { for (1, 2, 3) { 1; } 1, 2 }, 2 ],

 [ sub { while (1) { } },         0 ],
 [ sub { while (1) { 1; } 1, 2 }, 2 ],
);

my $i = 1;
for (@tests) {
 my $r = $sn->nary($_->[0]);
 is_deeply($r, { $_->[1] => 1 }, 'list test ' . $i);
 ++$i;
}
