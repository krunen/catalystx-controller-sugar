package CatalystX::Controller::Sugar;

=head1 NAME

CatalystX::Controller::Sugar - Extra sugar for Catalyst controller

=head1 VERSION

0.01

=head1 SYNOPSIS

 use CatalystX::Controller::Sugar;

 private foo => sub {
   res->body("Hey!");
 };

 chained "/" => "part" => sub {
   stash answer => 42;
 };

 chained "/part" => "endpoint/" => sub {
   res->body("The answer is: " .stash("answer"));
 };

 chained "/" => "multimethod" => {
   post => sub { ... },
   get => sub { ... },
   delete => sub { ... },
 };

=cut

use Moose;
use Moose::Exporter;
use MooseX::MethodAttributes ();
use Catalyst::Controller ();
use Catalyst::Utils;

Moose::Exporter->setup_import_methods(
    as_is => [qw/ session stash req res /],
    with_caller => [qw/ chained private /],
    also  => [qw/ Moose MooseX::MethodAttributes /],
);

our $VERSION = "0.01";
our($RES, $REQ, $CONTEXT, %CAPTURED);

=head1 EXPORTED FUNCTIONS

=head2 chained

 chained $Chained => $PathPart => sub { };
 chained $Chained => $PathPart => \@CaptureArgs => sub { };
 chained $Chained => "$PathPart" => $Args => sub { };
 chained $Chained => "$PathPart" => ... => \%method_map;

Same as:

 sub "$Chained/$PathPart" : Chained() PathPart() Args { }
 sub "$Chained/$PathPart" : Chained() PathPart() CaptureArgs() { }
 sub "$Chained/$PathPart" : Chained() PathPart() Args() { }

C<@CaptureArgs> is a list of names of the captured argumenst, which
can be retrieved using L<captured>.

C<$Args> is a number of Args to capture at the end of the chain.

C<%method_map> can be used if you want to dispatch to a specific method,
for a certain HTTP method: (The HTTP method is in lowercase)

 %method_map = (
    post => sub { ... },
    get => sub { ... },
    delete => sub { ... },
    #...
 );

=cut

sub chained {
    my $class = shift;
    my $code  = pop;
    my %attrs = map { $_, [shift(@_)] } qw/Chained PathPart CaptureArgs/;
    my($c, $name, $ns, $named_captures);

    $c  = Catalyst::Utils::class2appclass($class);
    $ns = $class->action_namespace($c);

    # CaptureArgs or Args?
    if(defined $attrs{'CaptureArgs'}->[0]) {
        if(ref $attrs{'CaptureArgs'}->[0] eq 'ARRAY') {
            $named_captures = $attrs{'CaptureArgs'}->[0];
            $attrs{'CaptureArgs'}->[0] = @$named_captures;
        }
        else {
            $attrs{'Args'} = delete $attrs{'CaptureArgs'};
        }
    }
    else {
        $attrs{'Args'} = delete $attrs{'CaptureArgs'};
    }

    $name =  $attrs{'Chained'}->[0] ."/" .$attrs{'PathPart'}->[0];
    $name =~ s,//,/,g;
    $name =~ s,^/,,;

    $c->dispatcher->register($c,
        $class->create_action(
            name => $name,
            reverse => $ns ? "$ns/$name" : $name,
            namespace => $ns,
            attributes => \%attrs,
            code => sub {
                _wrap_chained({
                    code => $code,
                    named_captures => $named_captures,
                    args => \@_,
                });
            },
        )
    );
}

sub _wrap_chained {
    my $args = shift;
    my $code = $args->{'code'};

    local $CONTEXT  = $args->{'args'}[1];
    local $RES      = $CONTEXT->res;
    local $REQ      = $CONTEXT->req;
    local %CAPTURED = _setup_captured($args->{'named_captures'});

    if(ref $code eq 'HASH') {
        my $method = lc $REQ->method;
        if($code->{$method}) {
            return $code->{$method}->(@{ $args->{'args'} });
        }
        else {
            confess "chained(..., { '$method' => undef })";
        }
    }
    else {
        return $code->(@{ $args->{'args'} });
    }
}

sub _setup_captured {
    my @names = ref $_[0] ? @{ $_[0] } : ();

    return map { shift(@names), $_ } @{ $REQ->captures };
}

=head2 private

 private $name => sub {};

Same as:

 sub $name :Private {};

=cut

sub private {
    my($class, $name, $code) = @_;
    my($c, $ns);
 
    $c  = Catalyst::Utils::class2appclass($class);
    $ns = $class->action_namespace($c);

    $c->dispatcher->register($c,
        $class->create_action(
            name => $name,
            code => sub { _wrap_private($code, @_) },
            reverse => $ns ? "$ns/$name" : $name,
            namespace => $ns,
            attributes => { Private => [] },
        )
    );
}

sub _wrap_private {
    my($code, $self);

    ($code, $self, $CONTEXT) = @_;

    local $RES = $CONTEXT->res;
    local $REQ = $CONTEXT->req;

    return $code->($self, $CONTEXT, @_);
}

=head2 res

 $response_obj = res;

=head2 req

 $request_obj = req;

=cut

sub res { $RES }
sub req { $REQ }

=head2 captured

 $value = captured($name);

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
