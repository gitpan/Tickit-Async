#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2011 -- leonerd@leonerd.org.uk

package Tickit::Async;

use strict;
use warnings;
use base qw( Tickit IO::Async::Notifier );
IO::Async::Notifier->VERSION( '0.43' ); # Need support for being a nonprinciple mixin

our $VERSION = '0.10';

use IO::Async::Loop;
use IO::Async::Signal;
use IO::Async::Stream;
use Term::TermKey::Async;

=head1 NAME

C<Tickit::Async> - use C<Tickit> with C<IO::Async>

=head1 SYNOPSIS

 use IO::Async;
 use Tickit::Async;

 my $tickit = Tickit::Async->new;

 # Create some widgets
 # ...

 $tickit->set_root_widget( $rootwidget );

 my $loop = IO::Async::Loop->new;
 $loop->add( $tickit );

 $tickit->run;

=head1 DESCRIPTION

This class allows a L<Tickit> user interface to run alongside other
L<IO::Async>-driven code, using C<IO::Async> as a source of IO events.

As a shortcut convenience, if the C<run> method is invoked and the object is
not yet a member of an L<IO::Async::Loop>, then a new one will be constructed
and the C<Tickit::Async> object added to it. This will allow a
C<Tickit::Async> object to be used without being aware it is not a simple
C<Tickit> object.

=cut

sub new
{
   my $class = shift;
   my $self = $class->Tickit::new( @_ );

   $self->add_child( IO::Async::Signal->new( 
      name => "WINCH",
      on_receipt => $self->_capture_weakself( "_SIGWINCH" ),
   ) );

   return $self;
}

sub _make_termkey
{
   my $self = shift;
   my ( $in ) = @_;

   my $tka = Term::TermKey::Async->new(
      term => $in,
      on_key => $self->_capture_weakself( "_KEY" ),
   );
   $self->add_child( $tka );

   return $tka;
}

sub _make_writer
{
   my $self = shift;
   my ( $out ) = @_;

   my $writer = IO::Async::Stream->new(
      write_handle => $out,
      autoflush => 1,
   );

   $self->add_child( $writer );

   return $writer;
}

sub _add_to_loop
{
   my $self = shift;

   $self->SUPER::_add_to_loop( @_ );

   if( $self->{todo_queue} ) {
      $self->get_loop->later( sub { $self->_flush_later } );
   }
}

sub later
{
   my $self = shift;
   my ( $code ) = @_;

   if( my $loop = $self->get_loop ) {
      $loop->later( $code );
   }
   else {
      push @{ $self->{todo_queue} }, $code;
   }
}

sub _STOP
{
   my $self = shift;
   $self->get_loop->loop_stop;
}

sub run
{
   my $self = shift;

   my $loop = $self->get_loop || do {
      my $newloop = IO::Async::Loop->new;
      $newloop->add( $self );
      $newloop;
   };

   $self->start;

   my $old_DIE = $SIG{__DIE__};
   local $SIG{__DIE__} = sub {
      local $SIG{__DIE__} = $old_DIE;

      die @_ if $^S;

      $self->stop;
      die @_;
   };

   $loop->loop_forever;
   $self->stop;
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
