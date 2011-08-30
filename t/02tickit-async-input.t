#!/usr/bin/perl

use strict;

# We need a UTF-8 locale to force libtermkey into UTF-8 handling, even if the
# system locale is not
# We also need to fool libtermkey into believing TERM=xterm even if it isn't,
# so we can reliably control it with fake escape sequences
BEGIN {
   $ENV{LANG} .= ".UTF-8" unless $ENV{LANG} =~ m/\.UTF-8$/;
   $ENV{TERM} = "xterm";
}

use Test::More tests => 8;
use IO::Async::Test;

use IO::Async::Loop;

use Tickit::Async;

my $loop = IO::Async::Loop->new();
testing_loop( $loop );

my ( $term_rd, $my_wr ) = $loop->pipepair or die "Cannot pipepair - $!";

my $tickit = Tickit::Async->new(
   term_in  => $term_rd,
);

$loop->add( $tickit );

{
   my @key_events;
   my @mouse_events;

   # We can't get at the key/mouse events easily from outside, so we'll hack it

   no warnings 'redefine';
   local *Tickit::on_key = sub {
      my ( $self, $type, $str, $key ) = @_;
      push @key_events, [ $type => $str ];
      isa_ok( $key, "Term::TermKey::Key", '$key' );
   };
   local *Tickit::on_mouse = sub {
      my ( $self, $ev, $button, $line, $col ) = @_;
      push @mouse_events, [ $ev => $button, $line, $col ];
   };

   $my_wr->syswrite( "h" );

   undef @key_events;
   wait_for { @key_events };

   is_deeply( \@key_events, [ [ text => "h" ] ], 'on_key h' );

   $my_wr->syswrite( "\cA" );

   undef @key_events;
   wait_for { @key_events };

   is_deeply( \@key_events, [ [ key => "C-a" ] ], 'on_key Ctrl-A' );

   # We'll test with a Unicode character outside of Latin-1, to ensure it
   # roundtrips correctly
   #
   # 'ĉ' [U+0109] - LATIN SMALL LETTER C WITH CIRCUMFLEX
   #  UTF-8: 0xc4 0x89

   $my_wr->syswrite( "\xc4\x89" );

   undef @key_events;
   wait_for { @key_events };

   is_deeply( \@key_events, [ [ text => "\x{109}" ] ], 'on_key reads UTF-8' );

   # Mouse encoding == CSI M $b $x $y
   # where $b, $l, $c are encoded as chr(32+$). Position is 1-based
   $my_wr->syswrite( "\e[M".chr(32+0).chr(32+21).chr(32+11) );

   undef @mouse_events;
   wait_for { @mouse_events };

   # Tickit::Term reports position 0-based
   is_deeply( \@mouse_events, [ [ press => 1, 10, 20 ] ], 'on_mouse press(1) @20,10' );
}

my $got_Ctrl_A;
$tickit->bind_key( "C-a" => sub { $got_Ctrl_A++ } );

$my_wr->syswrite( "\cA" );

wait_for { $got_Ctrl_A };

is( $got_Ctrl_A, 1, 'bind Ctrl-A' );

$loop->remove( $tickit );
