#!/usr/bin/perl

use strict;

# We need a UTF-8 locale to force libtermkey into UTF-8 handling, even if the
# system locale is not
BEGIN {
   $ENV{LANG} .= ".UTF-8" unless $ENV{LANG} =~ m/\.UTF-8$/;
}

use Test::More tests => 8;
use Test::HexString;
use Test::Refcount;
use IO::Async::Test;

use IO::Async::Loop;

use Tickit::Async;

my $loop = IO::Async::Loop->new();
testing_loop( $loop );

my ( $my_rd, $term_wr ) = $loop->pipepair or die "Cannot pipepair - $!";

my $tickit = Tickit::Async->new(
   term_out => $term_wr,
);

isa_ok( $tickit, 'Tickit::Async', '$tickit' );
is_oneref( $tickit, '$tickit has refcount 1 initially' );

my $term = $tickit->term;

isa_ok( $term, 'Tickit::Term', '$tickit->term' );

$loop->add( $tickit );

is_refcount( $tickit, 2, '$tickit has refcount 2 after $loop->add' );

# There might be some terminal setup code here... Flush it
$my_rd->blocking( 0 );
sysread( $my_rd, my $buffer, 8192 );

my $stream = "";
sub stream_is
{
   my ( $expect, $name ) = @_;

   wait_for_stream { length $stream >= length $expect } $my_rd => $stream;

   is_hexstr( substr( $stream, 0, length $expect, "" ), $expect, $name );
}

$term->print( "Hello" );

$stream = "";
stream_is( "Hello", '$term->print' );

# We'll test with a Unicode character outside of Latin-1, to ensure it
# roundtrips correctly
#
# 'ĉ' [U+0109] - LATIN SMALL LETTER C WITH CIRCUMFLEX
#  UTF-8: 0xc4 0x89

$term->print( "\x{109}" );
$stream = "";
stream_is( "\xc4\x89", 'print outputs UTF-8' );

is_refcount( $tickit, 2, '$tickit has refcount 2 before $loop->remove' );

$loop->remove( $tickit );

is_oneref( $tickit, '$tickit has refcount 1 at EOF' );
