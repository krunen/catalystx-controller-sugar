package CatalystX::Controller::Sugar;

=head1 NAME

CatalystX::Controller::Sugar - Extra sugar for Catalyst controller

=head1 SYNOPSIS

 use CatalystX::Controller::Sugar;

 sub foo :Local {
    my($self, $c) = @_; # not required

    stash name => "John Doe";
    session id => rand 999_999_999;

    # ...
 }

=cut

use Moose;
use Moose::Exporter;
use MooseX::MethodAttributes ();
use Catalyst::Controller ();

Moose::Exporter->setup_import_methods(
    as_is => [qw/ session stash req res /],
    with_caller => [qw/ chained private /],
    also  => [qw/ Moose MooseX::MethodAttributes /],
);

our($RES, $REQ, $C);

sub _wrapper {
    my $next = shift;
    my $self = shift;

    local $C   = shift;
    local $RES = $C->res;
    local $REQ = $C->req;

    if(ref $next eq 'HASH') {
        my $method = lc $REQ->method;
        if($next->{$method}) {
            return $next->{$method}->($self, $C, @_);
        }
        else {
            die "NO SUCH HTTP METHOD\n";
        }
    }
    else {
        return $next->($self, $C, @_);
    }
};

=head1 EXPORTED FUNCTIONS

=head2 res

 $response_obj = res;

=head2 req

 $request_obj = req;

=cut

sub res { $RES }
sub req { $REQ }

=head2 private

 private $name => sub {};

Same as:

 sub $name :Private {};

=cut

sub private {
    my $class = shift;
    my $name  = shift;
    my $code  = pop;
    my($c, $ns);
 
    $c  = ($class =~ /^(.*)::C(?:ontroller)?::/)[0];
    $ns = $class->action_namespace($c);

    $c->dispatcher->register($c,
        $class->create_action(
            name => $name,
            code => sub { _wrapper($code, @_) },
            reverse => $ns ? "$ns/$name" : $name,
            namespace => $ns,
            attributes => { Private => [] },
        )
    );
}

=head2 chained

 chained $Chained => $PathPart => sub { };
 chained $Chained => $PathPart => $CaptureArgs => sub { };
 chained $Chained => "$PathPart/" => $Args => sub { };
 chained $Chained => "$PathPart/" => ... => { post => sub {}, ... };

Same as:

 sub "$Chained/$PathPart" : Chained() PathPart() { }
 sub "$Chained/$PathPart" : Chained() PathPart() CaptureArgs() { }
 sub "$Chained/$PathPart" : Chained() PathPart() Args() { }

=cut

sub chained {
    my $class = shift;
    my $code  = pop;
    my %attrs = map { $_, [shift(@_)] } qw/Chained PathPart CaptureArgs/;
    my($c, $name, $ns);

    $c  = ($class =~ /^(.*)::C(?:ontroller)?::/)[0];
    $ns = $class->action_namespace($c);

    # endpoint
    if($attrs{'PathPart'}->[0] =~ s,/$,,) {
        $attrs{'Args'} = delete $attrs{'CaptureArgs'};
    }

    $name =  $attrs{'Chained'}->[0] ."/" .$attrs{'PathPart'}->[0];
    $name =~ s,//,/,g;
    $name =~ s,^/,,;

    $c->dispatcher->register($c,
        $class->create_action(
            name => $name,
            code => sub { _wrapper($code, @_) },
            reverse => $ns ? "$ns/$name" : $name,
            namespace => $ns,
            attributes => \%attrs,
        )
    );
}

=head2 stash

 $hash_ref = stash $key => $value, ...;
 $value = stash $key;

Set/get data from the stash.

=cut

sub stash {
    my $c = $C || _get_context_object();

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
    my $c = $C || _get_context_object();

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
