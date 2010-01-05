package CatalystX::Controller::Sugar;

=head1 NAME

CatalystX::Controller::Sugar - Sugar for Catalyst controller

=head1 VERSION

0.06

=head1 DESCRIPTION

This module is written to simplify the way controllers are written. I
personally think that shifting off C<$c> and C<$self> in every action is
tidious. I also wanted a simpler API to created chained actions, since I
rarely use any other actions - except of L</private>.

=head1 SYNOPSIS

  package MyApp::Controller::Root;
  use CatalystX::Controller::Sugar;
 
  __PACKAGE__->config->{'namespace'} = q();
 
  # Private action
  private authenticate => sub {
    c->user_exists and return 1;
  };
 
  # Chain /
  chain sub {
    report debug => 'Someone tries to access %s', c->action;
  };

  # Endpioint /*
  chain '' => sub {
    res->body('not found');
  };

  # Endpoint /login
  chain login => {
    get => sub {}, # show template
    post => sub {
      forward 'authenticate' and go '';
    },
  };
 
  # Chain /user/[id]/*
  chain user => ['id'], sub {
    stash user => c->model('DB::User')->find($_[0]);
  };
 
  # Endpoint /user/[id]/view/*
  chain 'user:1' => view => sub {
    res->body(
      sprintf 'Person is called: %s', stash->{'user'}->name
    );
  };
 

=head1 NOTE

C<$self> and C<$c> is not part of the argument list inside a
L<chain()> or L<private()> action. C<$c> is acquired by calling L<c()>,
and C<$self> is available by calling L<controller()>.

=cut

use Moose;
use Moose::Exporter;
use namespace::autoclean ();
use Catalyst::Controller ();
use Catalyst::Utils;
use Data::Dumper ();

Moose::Exporter->setup_import_methods(
    with_meta => [qw/ chain private /],
    as_is => [qw/ c captured controller forward go req report res session stash /],
    also => 'Moose',
);

our $VERSION = '0.06';
our $ROOT = 'root'; # will be deprecated
our $DEFAULT = 'default'; # will be deprecated
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
    my $class = shift->name;
    my $code = pop;
    my($c, $name, $ns, $attrs, $path, $action);

    $c     = Catalyst::Utils::class2appclass($class);
    $ns    = $class->action_namespace($c) || q();
    $attrs = _setup_chain_attrs($ns, @_);

    $path  =  $attrs->{'Chained'}[0];
    $path  =~ s,$ROOT$,,;
    $path .=  $attrs->{'PathPart'}[0];

    if($path ne "/$ns") {
        $name = (split "/", $attrs->{'PathPart'}[0])[-1];
    }
    elsif($c->dispatcher->get_action($ROOT, $ns)) {
        $name = $DEFAULT;
    }
    else {
        $name = $ROOT;
    }

    # add captures to name
    if(@{ $attrs->{'capture_names'} }) {
        $name ||= q();
        $name  .= ":" .int @{ $attrs->{'capture_names'} };
    }

    # set default name
    # is this correct?
    elsif(!$name) {
        $name = $DEFAULT;
    }

    $action = $class->create_action(
                  name => $name,
                  code => _create_chain_code($class, $code),
                  reverse => $ns ? "$ns/$name" : $name,
                  namespace => $ns,
                  class => $class,
                  attributes => $attrs,
              );

    $c->dispatcher->register($c, $action);
}

sub _setup_chain_attrs {
    my $ns    = shift;
    my $attrs = {};

    if(@_) { # chain ... => sub {};
        if(ref $_[-1] eq 'ARRAY') {
            $attrs->{'CaptureArgs'} = [int @{ $_[-1] }];
            $attrs->{'capture_names'} = pop @_;
        }
        elsif(defined $_[-1] and $_[-1] =~ /^(\d+)$/) {
            $attrs->{'Args'} = [pop @_];
        }

        if(defined $_[-1]) {
            $attrs->{'PathPart'} = [pop @_];
        }
        else {
            my $args = join ", ", @_;
            confess "Invalid arguments: chain($args)";
        }

        if(defined $_[-1]) {
            my $with = pop @_;
            $attrs->{'Chained'} = [ $with =~ m,^/, ? $with
                                  : $ns            ? "/$ns/$with"
                                  :                  "/$with"
                                  ];
        }
        else {
            $attrs->{'Chained'} = [$ns ? "/$ns/$ROOT" : "/$ROOT"];
        }
    }
    else { # chain sub {};
        my($parent, $this) = $ns =~ m[ ^ (.*)/(\w+) $ ]x;
        my $chained = $parent ? "/$parent/$ROOT"
                    : $ns     ? "/$ROOT"
                    :           "/";

        $attrs->{'Chained'}     = [$chained];
        $attrs->{'PathPart'}    = [$this || $ns];
        $attrs->{'CaptureArgs'} = [0];
    }

    $attrs->{'Args'} = [] unless($attrs->{'CaptureArgs'});
    $attrs->{'capture_names'} ||= [];

    return $attrs;
}

sub _create_chain_code {
    my($class, $code) = @_;

    if(ref $code eq 'HASH') {
        return sub {
            local $SELF     = shift;
            local $CONTEXT  = shift;
            local $RES      = $CONTEXT->res;
            local $REQ      = $CONTEXT->req;
            local %CAPTURED = _setup_captured();
            my $method      = lc $REQ->method;

            if($code->{$method}) {
                return $code->{$method}->(@_);
            }
            elsif($code->{'default'}) {
                return $code->{'default'}->(@_);
            }
            else {
                confess "Invalid arguments: chain(.., { '$method' => undef })";
            }
        };
    }
    else {
        return sub {
            local $SELF     = shift;
            local $CONTEXT  = shift;
            local $RES      = $CONTEXT->res;
            local $REQ      = $CONTEXT->req;
            local %CAPTURED = _setup_captured();

            return $code->(@_);
        };
    }
}

sub _setup_captured {
    my @names;

    for my $action (@{ $CONTEXT->action->chain }) {
        push @names, @{ $action->attributes->{'capture_names'} };
    }

    return map { shift(@names), $_ } @{ $REQ->captures };
}

=head2 private

 private $name => sub {};

Same as:

 sub $name :Private {}

=cut

sub private {
    my($meta, $name, $code) = @_;
    my $class = $meta->name;
    my($c, $ns);
 
    $c  = Catalyst::Utils::class2appclass($class);
    $ns = $class->action_namespace($c);

    $c->dispatcher->register($c,
        $class->create_action(
            name => $name,
            code => _create_private_code($class, $code),
            reverse => $ns ? "$ns/$name" : $name,
            namespace => $ns,
            class => $class,
            attributes => { Private => [] },
        )
    );
}

sub _create_private_code {
    my($class, $code) = @_;

    return sub {
        local $SELF    = shift;
        local $CONTEXT = shift;
        local $RES     = $CONTEXT->res;
        local $REQ     = $CONTEXT->req;

        return $code->(@_);
    };
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

    map {
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

    Moose->init_meta(%options);

    $options{'for_class'}->meta->superclasses(qw/Catalyst::Controller/);

    namespace::autoclean->import(-cleanee => $options{'for_class'});

    return $options{'for_class'}->meta;
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
