package Sub::Nary;

use 5.008001;

use strict;
use warnings;

use Carp qw/croak/;
use List::Util qw/reduce sum/;

use B qw/class ppname svref_2object OPf_KIDS/;

=head1 NAME

Sub::Nary - Try to count how many elements a subroutine can return in list context.

=head1 VERSION

Version 0.02

=cut

our $VERSION;
BEGIN {
 $VERSION  = '0.02';
}

=head1 SYNOPSIS

    use Sub::Nary;

    my $sn = Sub::Nary->new();
    my $r  = $sn->nary(\&hlagh);

=head1 DESCRIPTION

This module uses the L<B> framework to walk into subroutines and try to guess how many scalars are likely to be returned in list context. It's not always possible to give a definitive answer to this question at compile time, so the results are given in terms of "probability of return" (to be understood in a sense described below).

=head1 METHODS

=head2 C<new>

The usual constructor. Currently takes no argument.

=head2 C<nary $coderef>

Takes a code reference to a named or anonymous subroutine, and returns a hash reference whose keys are the possible numbers of returning scalars, and the corresponding values the "probability" to get them. The special key C<'list'> is used to denote a possibly infinite number of returned arguments. The return value hence would look at

    { 1 => 0.2, 2 => 0.4, 4 => 0.3, list => 0.1 }

that is, we should get C<1> scalar C<1> time over C<5> and so on. The sum of all values is C<1>. The returned result, and all the results obtained from intermediate subs, are cached into the object.

=head2 C<flush>

Flushes the L<Sub::Nary> object cache. Returns the object itself.

=head1 PROBABILITY OF RETURN

The probability is computed as such :

=over 4

=item * All the returning points in the same subroutine (i.e. all the explicit C<return> and the last computed value) are considered equally possible.

For example, the subroutine

    sub simple {
     if (rand < 0.1) {
      return 1;
     } else {
      return 2, 3;
     }
    }

is seen returning one or two arguments each with probability C<1/2>.
As for

    sub hlagh {
     my $x = rand;
     if ($x < 0.1) {
      return 1, 2, 3;
     } elsif ($x > 0.9) {
      return 4, 5;
     }
    }

it is considered to return C<1> (when the two tests fail, the last computed value is returned, which here is C<< $x > 0.9 >> evaluated in the scalar context of the test), C<2> or C<3> arguments each with probability C<1/3>.

=item * The total probability law for a given returning point is the convolution product of the probabilities of its list elements.

As such, 

    sub notsosimple {
     return 1, simple(), 2
    }

returns C<3> or C<4> arguments with probability C<1/2> ; and

    sub double {
     return simple(), simple()
    }

never returns C<1> argument but returns C<2> with probability C<1/2 * 1/2 = 1/4>, C<3> with probability C<1/2 * 1/2 + 1/2 * 1/2 = 1/2> and C<4> with probability C<1/4> too.

=item * If a core function may return different numbers of scalars, each kind is considered equally possible.

For example, C<stat> returns C<13> elements on success and C<0> on error. The according probability will then be C<< { 0 => 0.5, 13 => 0.5 } >>.

=item * The C<list> state is absorbing in regard of all the other ones.

This is just a pedantic way to say that "list + fixed length = list".
That's why

    sub listy {
     return 1, simple(), @_
    }

is considered as always returning an unbounded list.

Also, the convolution law does not behave the same when C<list> elements are involved : in the following example,

    sub oneorlist {
     if (rand < 0.1) {
      return 1
     } else {
      return @_
     }
    }

    sub composed {
     return oneorlist(), oneorlist()
    }

C<composed> returns C<2> scalars with probability C<1/2 * 1/2 = 1/4> and a C<list> with probability C<3/4>.

=back

=cut

BEGIN {
 require XSLoader;
 XSLoader::load(__PACKAGE__, $VERSION);
}

sub _check_self {
 croak 'First argument isn\'t a valid ' . __PACKAGE__ . ' object'
  unless ref $_[0] and $_[0]->isa(__PACKAGE__);
}

sub new {
 my $class = shift;
 $class = ref($class) || $class || __PACKAGE__;
 bless { cache => { } }, $class;
}

sub flush {
 my $self = shift;
 _check_self($self);
 $self->{cache} = { };
 $self;
}

sub nary {
 my $self = shift;
 my $sub  = shift;

 $self->{cv} = [ ];
 return $self->enter(svref_2object($sub));
}

sub name ($) {
 my $n = $_[0]->name;
 $n eq 'null' ? substr(ppname($_[0]->targ), 3) : $n
}

sub combine {
 reduce {{
  my %res;
  my $la = delete $a->{list};
  my $lb = delete $b->{list};
  if (defined $la || defined $lb) {
   $la ||= 0;
   $lb ||= 0;
   $res{list} = $la + $lb - $la * $lb;
  }
  while (my ($ka, $va) = each %$a) {
   $ka = int $ka;
   while (my ($kb, $vb) = each %$b) {
    my $key = $ka + int $kb;
    $res{$key} += $va * $vb;
   }
  }
  \%res
 }} map { (ref) ? $_ : { $_ => 1 } } grep defined, @_;
}

sub add {
 reduce {
  $a->{$_} += $b->{$_} for keys %$b;
  $a
 } map { (ref) ? $_ : { $_ => 1 } } grep defined, @_;
}

my %ops;

$ops{$_} = 1      for scalops;
$ops{$_} = 0      for qw/stub nextstate/;
$ops{$_} = 1      for qw/padsv/;
$ops{$_} = 'list' for qw/padav/;
$ops{$_} = 'list' for qw/padhv rv2hv/;
$ops{$_} = 'list' for qw/padany match entereval readline/;

$ops{each}      = { 0 => 0.5, 2 => 0.5 };
$ops{stat}      = { 0 => 0.5, 13 => 0.5 };

$ops{caller}    = sub { my @a = caller 0; scalar @a }->();
$ops{localtime} = do { my @a = localtime; scalar @a };
$ops{gmtime}    = do { my @a = gmtime; scalar @a };

$ops{$_} = { 0 => 0.5, 10 => 0.5 } for map "gpw$_", qw/nam uid ent/;
$ops{$_} = { 0 => 0.5, 4 => 0.5 }  for map "ggr$_", qw/nam gid ent/;
$ops{$_} = 'list'                  for qw/ghbyname ghbyaddr ghostent/;
$ops{$_} = { 0 => 0.5, 4 => 0.5 }  for qw/gnbyname gnbyaddr gnetent/;
$ops{$_} = { 0 => 0.5, 3 => 0.5 }  for qw/gpbyname gpbynumber gprotoent/;
$ops{$_} = { 0 => 0.5, 4 => 0.5 }  for qw/gsbyname gsbyport gservent/;

sub enter {
 my ($self, $cv) = @_;

 return 'list' if class($cv) ne 'CV';
 my $op  = $cv->ROOT;
 my $tag = tag($op);

 return { %{$self->{cache}->{$tag}} } if exists $self->{cache}->{$tag};

 # Anything can happen with recursion
 for (@{$self->{cv}}) {
  return 'list' if $tag == tag($_->ROOT);
 }

 unshift @{$self->{cv}}, $cv;
 (my $r, undef) = $self->expect_any($op->first);
 shift @{$self->{cv}};

 $r = { $r => 1} unless ref $r;
 my $total = sum values %$r;
 $r = { map { $_ => $r->{$_} / $total } keys %$r };
 $self->{cache}->{$tag} = { %$r };
 return $r;
}

sub expect_return {
 my ($self, $op) = @_;

 return ($self->expect_list($op))[0] => 1 if name($op) eq 'return';

 if ($op->flags & OPf_KIDS) {
  for ($op = $op->first; not null $op; $op = $op->sibling) {
   my ($p, $r) = $self->expect_return($op);
   return $p => 1 if $r;
  }
 }

 return;
}

sub expect_list {
 my ($self, $op) = @_;

 my $n = name($op);
 my $meth = $self->can('pp_' . $n);
 return $self->$meth($op) if $meth;
 if (exists $ops{$n}) {
  my $r = $ops{$n};
  $r = { %$r } if ref $r eq 'HASH';
  return $r => 0;
 }

 if ($op->flags & OPf_KIDS) {
  my @res = (0);
  my ($p, $r);
  for ($op = $op->first; not null $op; $op = $op->sibling) {
   my $n = name($op);
   next if $n eq 'pushmark';
   if ($n eq 'nextstate'
       and not null(($op = $op->sibling)->sibling)) {
    ($p, $r) = $self->expect_return($op);
    return $p => 1 if $r;
   } else {
    ($p, $r) = $self->expect_any($op);
    return $p => 1 if $r;
    push @res, $p;
   }
  }
  return (combine @res) => 0;
 }

 return;
}

sub expect_any {
 my ($self, $op) = @_;

 return ($self->expect_list($op))[0] => 1 if name($op) eq 'return';

 if (class($op) eq 'LOGOP' and not null $op->first) {
  my @res;
  my ($p, $r);

  my $op   = $op->first;
  ($p, $r) = $self->expect_return($op);
  return $p => 1 if $r;

  $op = $op->sibling;
  push @res, ($self->expect_any($op))[0];

  # If the logop has no else branch, it can also return the *scalar* result of
  # the conditional
  $op = $op->sibling;
  if (null $op) {
   push @res, 1;
  } else {
   push @res, ($self->expect_any($op))[0];
  }

  return (add @res) => 0;
 }

 return $self->expect_list($op);
}

# Stolen from B::Deparse

sub padval { $_[0]->{cv}->[0]->PADLIST->ARRAYelt(1)->ARRAYelt($_[1]) }

sub gv_or_padgv {
 my ($self, $op) = @_;
 if (class($op) eq 'PADOP') {
  return $self->padval($op->padix)
 } else { # class($op) eq "SVOP"
  return $op->gv;
 }
}

sub const_sv {
 my ($self, $op) = @_;
 my $sv = $op->sv;
 # the constant could be in the pad (under useithreads)
 $sv = $self->padval($op->targ) unless $$sv;
 return $sv;
}

sub pp_entersub {
 my ($self, $op, $exp) = @_;

 my $next = $op;
 while ($next->flags & OPf_KIDS) {
  $next = $next->first;
 }
 while (not null $next) {
  $op = $next;
  my ($p, $r) = $self->expect_return($op, $exp);
  return $p => 1 if $r;
  $next = $op->sibling;
 }

 if (name($op) eq 'rv2cv') {
  my $n;
  do {
   $op = $op->first;
   my $next = $op->sibling;
   while (not null $next) {
    $op   = $next;
    $next = $next->sibling;
   }
   $n  = name($op)
  } while ($op->flags & OPf_KIDS and { map { $_ => 1 } qw/null leave/ }->{$n});
  return 'list' unless { map { $_ => 1 } qw/gv refgen/ }->{$n};
  local $self->{sub} = 1;
  return $self->expect_any($op, $exp);
 } else {
  # Method call ?
  return 'list';
 }
}

sub pp_gv {
 my ($self, $op) = @_;

 return $self->{sub} ? $self->enter($self->gv_or_padgv($op)->CV) : 1
}

sub pp_anoncode {
 my ($self, $op) = @_;

 return $self->{sub} ? $self->enter($self->const_sv($op)) : 1
}

sub pp_goto {
 my ($self, $op) = @_;

 my $n = name($op);
 while ($op->flags & OPf_KIDS) {
  my $nop = $op->first;
  my $nn  = name($nop);
  if ($nn eq 'pushmark') {
   $nop = $nop->sibling;
   $nn  = name($nop);
  }
  if ($n eq 'rv2cv' and $nn eq 'gv') {
   return $self->enter($self->gv_or_padgv($nop)->CV);
  }
  $op = $nop;
  $n  = $nn;
 }

 return 'list';
}

sub pp_const {
 my ($self, $op) = @_;

 my $sv = $self->const_sv($op);
 my $c = class($sv);
 if ($c eq 'AV') {
  return $sv->FILL + 1;
 } elsif ($c eq 'HV') {
  return 2 * $sv->FILL;
 }

 return 1;
}

sub pp_aslice { $_[0]->expect_any($_[1]->first->sibling) }

sub pp_hslice;
*pp_hslice = *pp_aslice{CODE};

sub pp_lslice { $_[0]->expect_any($_[1]->first) }

sub pp_rv2av {
 my ($self, $op) = @_;
 $op = $op->first;

 return (name($op) eq 'const') ? $self->expect_any($op) : 'list';
}

sub pp_aassign {
 my ($self, $op) = @_;

 $op = $op->first;

 # Can't assign to return
 my ($p, $r) = $self->expect_list($op->sibling);
 return $p => 0 if not exists $p->{list};

 $self->expect_any($op);
}

sub pp_leaveloop { $_[0]->expect_return($_[1]->first->sibling) }

sub pp_flip {
 my ($self, $op) = @_;

 $op = $op->first;
 return 'list' if name($op) ne 'range';

 my $begin = $op->first;
 if (name($begin) eq 'const') {
  my $end = $begin->sibling;
  if (name($end) eq 'const') {
   $begin  = $self->const_sv($begin);
   $end    = $self->const_sv($end);
   no warnings 'numeric';
   return int(${$end->object_2svref}) - int(${$begin->object_2svref}) + 1;
  } else {
   my ($p, $r) = $self->expect_return($end);
   return $p => 1 if $r;
  }
 } else {
  my ($p, $r) = $self->expect_return($begin);
  return $p => 1 if $r;
 }

 return 'list'
}

=head1 EXPORT

An object-oriented module shouldn't export any function, and so does this one.

=head1 CAVEATS

The algorithm may be pessimistic (things seen as C<list> while they are of fixed length) but not optimistic (the opposite, duh).

C<wantarray> isn't specialized when encountered in the optree.

=head1 DEPENDENCIES

L<perl> 5.8.1.

L<Carp> (standard since perl 5), L<B> (since perl 5.005), L<XSLoader> (since perl 5.006) and L<List::Util> (since perl 5.007003).

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on #perl @ FreeNode (vincent or Prof_Vince).

=head1 BUGS

Please report any bugs or feature requests to C<bug-b-nary at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Sub-Nary>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Sub::Nary

Tests code coverage report is available at L<http://www.profvince.com/perl/cover/Sub-Nary>.

=head1 ACKNOWLEDGEMENTS

Thanks to Sebastien Aperghis-Tramoni for helping to name this module.

=head1 COPYRIGHT & LICENSE

Copyright 2008 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Sub::Nary
