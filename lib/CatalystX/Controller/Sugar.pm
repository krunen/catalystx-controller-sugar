package CatalystX::Controller::Sugar;

=head1 NAME

CatalystX::Controller::Sugar - Extra sugar for Catalyst controller

=head1 SYNOPSIS

 use CatalystX::Controller::Sugar;

 sub foo :Local {
    my($self, $c) = @_;

    stash name => "John Doe";
    session id => rand 999_999_999;

    # ...
 }

=cut

use Moose;
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    as_is => [qw/ stash session /],
    with_caller => [qw/ init_meta /],
);

=head1 METHODS

=head2 stash

 $hash_ref = stash $key => $value, ...;
 $value = stash $key;

Set/get data from the stash.

=cut

sub stash {
    my $c = _get_context_object();

    if(@_ == 1) {
        return $c->stash->{$_[0]};
    }
    elsif(@_ % 2 == 0) {
        while(@_) {
            my($key, $value) = splice @_, 2;
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
    my $c = _get_context_object();

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
    () = caller(1);
    return $DB::args[1];
}

=head2 init_meta

See L<Moose::Exporter>.

=cut

sub init_meta {
    my $c = shift;
    my %p = @_;
    my $caller = $p{'for_class'};

    if($p{'superclasses'}) {
        push @{ $p{'superclasses'} }, "Catalyst::Controller";
    }
    else {
        $p{'superclasses'} = [ "Catalyst::Controller" ];
    }

    Moose->init_meta(%p);
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
