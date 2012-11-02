#!/usr/bin/perl

use strict;
use warnings;

use IO::Async::Loop;
use IO::Async::Timer::Periodic;
use Tickit::Async;

use Tickit::Widget::Static;

use Tickit::Widget::VBox;
use Tickit::Widget::Frame;

my $loop = IO::Async::Loop->new;

my $vbox = Tickit::Widget::VBox->new( spacing => 1 );

$vbox->add( Tickit::Widget::Frame->new(
      child => my $static = Tickit::Widget::Static->new(
         text => "Flashing text",
         align  => "centre",
         valign => "middle",
      ),
      style => "single",
) );

my $fg = 1;
$loop->add( IO::Async::Timer::Periodic->new(
      interval => 0.5,
      on_tick => sub {
         $fg++;
         $fg = 1 if $fg > 7;
         $static->pen->chattr( fg => $fg );
      },
)->start );

my $tickit = Tickit::Async->new;
$loop->add( $tickit );

$tickit->set_root_widget( $vbox );

$tickit->run;
