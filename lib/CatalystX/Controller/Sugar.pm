package CatalystX::Controller::Sugar;

=head1 NAME

CatalystX::Controller::Sugar - Extra sugar for Catalyst controller

=head1 VERSION

0.01

=head1 SYNOPSIS

 use CatalystX::Controller::Sugar;

 __PACKAGE__->config->{'namespace'} = q();

 private foo => sub {
   res->body("Hey!");
 };

 # /
 chain sub {
    # root chain
 };

 # /person/*
 chain "/" => "person" => ['id'], sub {
   stash unique => rand;
   res->print( captured('id') );
 };

 # /person/*/edit/*
 chain "/person" => "edit" => sub {
   res->body( sprintf "Person %s is unique: %s"
     captured('id'), stash('unique')
   );
 };

 # /multi
 chain "multi" => {
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
use MooseX::MethodAttributes ();
use Catalyst::Controller ();
use Catalyst::Utils;

Moose::Exporter->setup_import_methods(
    as_is => [qw/ c captured controller req res session stash /],
    with_caller => [qw/ chain private /],
    also  => [qw/ Moose MooseX::MethodAttributes /],
);

our $VERSION = "0.01";
our($RES, $REQ, $SELF, $CONTEXT, %CAPTURED);

=head1 EXPORTED FUNCTIONS

=head2 chain

 1. chain sub { };
 2. chain $PathPart => sub { };
 3. chain $Chained => $PathPart => sub { };
 4. chain $Chained => $PathPart => \@CaptureArgs, sub { };
 5. chain $Chained => $PathPart => $Args => sub { };
 6. chain $Chained => $PathPart => ..., \%method_map;

Same as:

 1. sub "/" : Chained(/) PathPart("") CaptureArgs { }
 2. sub "$PathPart" : Global($PathPart) { }
 3. sub "$Chained/$PathPart" : Chained() PathPart() Args { }
 4. sub "$Chained/$PathPart" : Chained() PathPart() CaptureArgs() { }
 5. sub "$Chained/$PathPart" : Chained() PathPart() Args() { }

C<@CaptureArgs> is a list of names of the captured argumenst, which
can be retrieved using L<captured()>.

C<$Args> is a number of Args to capture at the endpoint of a chain. These
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
    my $class = shift;
    my $code  = pop;
    my %attrs = map { $_, [shift(@_)] } qw/Chained PathPart CaptureArgs/;
    my($c, $self, $name, $ns);

    $c  = Catalyst::Utils::class2appclass($class);
    $ns = $class->action_namespace($c);

    _setup_chain_root(\%attrs);
    _setup_chain_args(\%attrs);

    $name = $attrs{'Chained'}->[0] ."/" .$attrs{'PathPart'}->[0];

    if($c->dispatcher->get_action("ROOT", $ns)) {
        $name                  = "ROOT/" .$name;
        $attrs{'Chained'}->[0] =~ s,/,/ROOT/,;
        $attrs{'Chained'}->[0] =~ s,/$,,;
    }

    $name   =~ s,/+,/,g;
    $name   =~ s,^/+,,;
    $name ||=  "ROOT";

    $attrs{'capture_names'} ||= [];

    $c->dispatcher->register($c,
        $class->create_action(
            name => $name,
            code => _create_chain_code($class, $code),
            reverse => $ns ? "$ns/$name" : $name,
            namespace => $ns,
            attributes => \%attrs,
        )
    );
}

# chain($path_part => sub {});
sub _setup_chain_root {
    my $attrs = shift;

    if(!defined $attrs->{'Chained'}->[0]) {
        $attrs->{'CaptureArgs'} = [[]];
        $attrs->{'PathPart'}    = [""];
        $attrs->{'Chained'}     = ["/"];
    }
    elsif(!defined $attrs->{'PathPart'}->[0]) {
        $attrs->{'PathPart'} = $attrs->{'Chained'};
        $attrs->{'Chained'}  = ["/"];
    }
}

# CaptureArgs or Args?
sub _setup_chain_args {
    my $attrs = shift;

    if(defined $attrs->{'CaptureArgs'}->[0]) {
        if(ref $attrs->{'CaptureArgs'}->[0] eq 'ARRAY') {
            $attrs->{'capture_names'} = $attrs->{'CaptureArgs'}->[0];
            $attrs->{'CaptureArgs'}->[0] = @{ $attrs->{'capture_names'} };
        }
        else {
            $attrs->{'Args'} = delete $attrs->{'CaptureArgs'};
        }
    }
    else {
        $attrs->{'Args'} = delete $attrs->{'CaptureArgs'};
    }
}

sub _create_chain_code {
    my($class, $code) = @_;

    if(ref $code eq 'HASH') {
        return sub {
            my $controller  = shift;
            my $method      = lc $_[0]->req->method;
            local $CONTEXT  = shift;
            local $SELF     = $class;
            local $RES      = $CONTEXT->res;
            local $REQ      = $CONTEXT->req;
            local %CAPTURED = _setup_captured();

            if($code->{$method}) {
                return $code->{$method}->(@_);
            }
            elsif($code->{'default'}) {
                return $code->{'default'}->(@_);
            }
            else {
                confess "chain(..., { '$method' => undef })";
            }
        };
    }
    else {
        return sub {
            my $controller  = shift;
            local $CONTEXT  = shift;
            local $SELF     = $class;
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

 sub $name :Private {};

=cut

sub private {
    return;
    my($class, $name, $code) = @_;
    my($c, $self, $ns);
 
    $c  = Catalyst::Utils::class2appclass($class);
    $ns = $class->action_namespace($c);

    $c->dispatcher->register($c,
        $class->create_action(
            name => $name,
            code => _create_private_code($class, $code),
            reverse => $ns ? "$ns/$name" : $name,
            namespace => $ns,
            attributes => { Private => [] },
        )
    );
}

sub _create_private_code {
    my($class, $code) = @_;

    return sub {
        my $controller = shift;
        local $CONTEXT = shift;
        local $SELF    = $class;
        local $RES     = $CONTEXT->res;
        local $REQ     = $CONTEXT->req;

        return $code->(@_);
    };
}

=head2 c

 $context_obj = c;

Returns the context object for this request.

=head2 controller

 $controller_obj = controller;

Returns the controller class.

=head2 req

 $request_obj = req;

Returns the request object for this request.

=head2 res

 $response_obj = res;

Returns the response object for this request.

=cut

sub c { $CONTEXT }
sub controller { $SELF }
sub req { $REQ }
sub res { $RES }

=head2 captured

 $value = captured($name);

Retrieve data captured in a chain, using the names set with L<chain()>.

 chain "/" => "user" => ["id"], sub {
   res->body( captured("id") );
 };

=cut

sub captured {
    return $CAPTURED{$_[0]};
}

=head2 stash

 $hash_ref = stash $key => $value, ...;
 $value = stash $key;

Set/get data from the stash.

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
    else {
        confess "stash(@_) is invalid";
    }

    return $c->stash;
}

=head2 session

 $hash_ref == session $key => $value;
 $value = session $key;

Set/get data from the session.

=cut

sub session {
    my $c = $CONTEXT || _get_context_object();

    if(@_ == 1) {
        return $c->session->{$_[0]};
    }
    elsif(@_ % 2 == 0) {
        while(@_) {
            my($key, $value) = splice @_, 2;
            $c->session->{$key} = $value;
        }
    }
    else {
        confess "session(@_) is invalid";
    }

    return $c->session;
}

sub _get_context_object {
    package DB;
    () = caller(2);
    return $DB::args[1];
}

=head2 init_meta

See L<Moose::Exporter>.

=cut

sub init_meta {
    my $c   = shift;
    my %p   = @_;
    my $for = $p{'for_class'};

    Moose->init_meta(%p);

    $for->meta->superclasses("Catalyst::Controller");
}

=head1 BUGS

Please report any bugs or feature requests to
C<bug-catalystx-controller-sugar at rt.cpan.org>, or through the web
interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CatalystX-Controller-Sugar>.
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
