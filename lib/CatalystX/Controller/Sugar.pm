package CatalystX::Controller::Sugar;

=head1 NAME

CatalystX::Controller::Sugar - Sugar for Catalyst controller

=head1 VERSION

0.05

=head1 DESCRIPTION

This module is written to simplify the way controllers are written. I
personally think that shifting off C<$c> and C<$self> in every action is
tidious. I also wanted a simpler API to created chained actions, since I
rarely use any other actions - except of L</private>.

=head1 SYNOPSIS

 use CatalystX::Controller::Sugar;

 __PACKAGE__->config->{'namespace'} = q();

 # Private action
 private foo => sub {
   res->body('Hey!');
 };

 # Chain /
 chain sub {
    # root chain
 };

 # Chain /person/[id]/
 chain '/' => 'person' => ['id'], sub {
   stash unique => rand;
   res->print( captured('id') );
 };

 # Endpoint /person/*/edit/*
 chain '/person:1' => 'edit' => sub {
   res->body( sprintf 'Person %s is unique: %s'
     captured('id'), stash('unique')
   );
 };

 # Endpoint /multi
 chain '/multi' => {
   post => sub { ... },
   get => sub { ... },
   delete => sub { ... },
   default => sub { ... },
 };

=head1 NOTE

C<$self> and C<$c> is not part of the argument list inside a
L<chain()> or L<private()> action. C<$c> is acquired by calling L<c()>,
and C<$self> is available by calling L<controller()>.

=cut

use Moose;
use Moose::Exporter;
use Catalyst::Controller ();
use Catalyst::Utils;
use Data::Dumper ();

Moose::Exporter->setup_import_methods(
    with_meta => [qw/ chain private /],
    as_is => [qw/ c captured controller forward go req report res session stash /],
    also => 'Moose',
);

our $VERSION = '0.05';
our $DEFAULT = 'default';
our $ROOT = 'root';
our($RES, $REQ, $SELF, $CONTEXT, %CAPTURED);

=head1 EXPORTED FUNCTIONS

=head2 chain

 1. chain sub { };

 2. chain $PathPart => sub { };
 3. chain $PathPart => $Int, sub { };
 4. chain $PathPart => \@CaptureArgs, sub { };

 5. chain $Chained => $PathPart => sub { };
 6. chain $Chained => $PathPart => $Int, sub { };
 7. chain $Chained => $PathPart => \@CaptureArgs, sub { };

 8. chain ..., \%method_map;

Same as:

 1. sub root : Chained('/') PathPart('') CaptureArgs(0) { }

 2. sub $PathPart : Chained('/root') Args { }
 3. sub $PathPart : Chained('/root') Args($Int) { }
 4. sub $PathPart : Chained('/root') CaptureArgs($Int) { }

 5. sub $PathPart : Chained($Chained) Args { }
 6. sub $PathPart : Chained($Chained) Args($Int) { }
 7. sub $PathPart : Chained($Chained) CaptureArgs($Int) { }

 8. Special case: See below

C<@CaptureArgs> is a list of names of the captured arguments, which
can be retrieved using L<captured()>.

C<$Int> is a number of Args to capture at the endpoint of a chain. These
cannot be aquired using L<captured()>, but is instead available in C<@_>.

C<%method_map> can be used if you want to dispatch to a specific method,
for a certain HTTP method: (The HTTP method is in lowercase)

 %method_map = (
    post => sub { ... },
    get => sub { ... },
    delete => sub { ... },
    default => sub { ... },
    #...
 );

=cut

sub chain {
    shift->add_chain_action(@_);
}

=head2 private

 private $name => sub {};

Same as:

 sub $name :Private {}

=cut

sub private {
    shift->add_private_action(@_);
}

=head2 forward

 @Any = forward $action;
 @Any = forward $action, \@arguments;

See L<Catalyst::forward()>.

=head2 go

 go $action;
 go $action, \@arguments;

See L<Catalyst::go()>.

=cut

sub forward { $CONTEXT->forward(@_) }
sub go { $CONTEXT->go(@_) }

=head2 c

 $context_obj = c;

Returns the context object for this request, an instance of L<Catalyst>.

=head2 controller

 $controller_obj = controller;

Returns the current controller object.

=head2 req

 $request_obj = req;

Returns the request object for this request, an instance of
L<Catalyst::Request>.

=head2 res

 $response_obj = res;

Returns the response object for this request, an instance of
L<Catalyst::Response>.

=cut

sub c { $CONTEXT }
sub controller { $SELF }
sub req { $REQ }
sub res { $RES }

=head2 captured

 $value = captured($name);

Retrieve data captured in a chain, using the names set with L<chain()>.

 chain '/' => 'user' => ['id'], sub {
   res->body( captured('id') );
 };

=cut

sub captured {
    return $CAPTURED{$_[0]};
}

=head2 stash

 $value = stash $key;
 $hash_ref = stash $key => $value, ...;
 $hash_ref = stash;

Set/get data from the stash. The C<$hash_ref> is a reference to what the
stash is holding.

This will be the same as:

 $c->stash->{$key} = $value;

=cut

sub stash {
    my $c = $CONTEXT || _get_context_object();

    if(@_ == 1) {
        return $c->stash->{$_[0]};
    }
    elsif(@_ % 2 == 0) {
        while(@_) {
            my($key, $value) = splice @_, 0, 2;
            $c->stash->{$key} = $value;
        }
    }

    return $c->stash;
}

=head2 session

 $value = session $key;
 $hash_ref == session $key => $value;
 $hash_ref == session;

Set/get data from the session. The C<$hash_ref> is a reference to what the
session is holding.

This function will only work if a session module/plugin is loaded into
L<Catalyst>.

=cut

sub session {
    my $c = $CONTEXT || _get_context_object();

    if(@_ == 1) {
        return $c->session->{$_[0]};
    }
    elsif(@_ % 2 == 0) {
        while(@_) {
            my($key, $value) = splice @_, 0, 2;
            $c->session->{$key} = $value;
        }
    }
    else {
        my $args = join ", ", @_;
        confess "Invalid arguments: session($args)";
    }

    return $c->session;
}

sub _get_context_object {
    package DB;
    () = caller(2);
    return $DB::args[1];
}

=head2 report

 report $level, $format, @args;

Almost the same as:

 $c->log->$level(sprintf $format, @args);

But undef values from C<@args> are turned into "__UNDEF__", and objects
and/or datastructructures are flatten, using L<Data::Dumper>.

=cut

sub report {
    my $level = shift;
    my $format = shift;
    my $c = $CONTEXT || _get_context_object();
    my $log = $c->log;

    if(my $check = $log->can("is_$level")) {
        if(!$log->$check) {
            return;
        }
    }
    
    return $log->$level(sprintf $format, _flatten(@_));
}

sub _flatten {
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Terse = 0;

    return map {
          ref $_     ? Data::Dumper::Dumper($_)
        : defined $_ ? $_
        :              '__UNDEF__'
    } @_;
}

=head2 METHODS

=head2 init_meta

See L<Moose::Exporter>.

=cut

sub init_meta {
    my $c = shift;
    my %options = @_;
    my $for = $options{'for_class'};

    Moose->init_meta(%options);

    $for->meta->superclasses(qw/Catalyst::Controller/),

    Moose::Util::MetaRole::apply_metaclass_roles(
        for_class => $for,
        metaclass_roles => [qw/CatalystX::Controller::Sugar::Meta::Role/],
    );

    return $for->meta;
}

=head1 BUGS

Please report any bugs or feature requests to
C<bug-catalystx-controller-sugar at rt.cpan.org>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2007 Jan Henning Thorsen, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Jan Henning Thorsen, C<< <jhthorsen at cpan.org> >>

=cut

1;
