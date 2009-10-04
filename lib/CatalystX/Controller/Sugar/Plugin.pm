package CatalystX::Controller::Sugar::Plugin;

=head1 NAME

CatalystX::Controller::Sugar::Plugin - Prepare plugin, not controller

=head1 DESCRIPTION

This module prepare actions to be plugged in "somewhere" in another
controller. This is done, by using the L</inject()> method.

=head1 SYNOPSIS

 #=========================================
 package My::Plugin;
 use CatalystX::Controller::Sugar::Plugin
 # Same as L<CatalystX::Controller::Sugar>.
 1;

 #=========================================
 package MyApp::Controller::Foo;
 use Moose;
 My::Plugin->inject;
 1;

=cut

use Moose;
use Moose::Exporter;
use Catalyst::Utils;
use Data::Dumper ();

Moose::Exporter->setup_import_methods(
    with_caller => [qw/ chain private /],
    as_is => [qw/ inject /],
);

=head1 EXPORTED FUNCTIONS

=head2 chain

Same as L<CatalystX::Controller::Sugar::chain()>, but will only prepare the
action to be injected in some other controller.

=cut

sub chain {
    my $class = shift;
    my $action_list = $class->get_package_symbol('@ACTIONS');
    push @$action_list, [chain => @_];
}

=head2 private

Same as L<CatalystX::Controller::Sugar::private()>, but will only prepare the
action to be injected in some other controller.

=cut

sub private {
    my $class = shift;
    my $action_list = $class->get_package_symbol('@ACTIONS');
    push @$action_list, [private => @_];
}

=head2 METHODS

=head2 inject

 $class->inject;
 $class->inject($target);

Will inject the prepared actions into C<$target> namespace or caller's
namespace by default.

=cut

sub inject {
    my $plugin = shift;
    my $target = shift || (caller(1))[0];
    my $sugar_meta = CatalystX::Controller::Sugar->meta;
    my $action_list = $plugin->get_package_symbol('@ACTIONS');

    unless(Class::MOP::is_class_loaded($target)) {
        _create_controller($target);
    }

    for my $action (@$action_list) {
        my($type, @args) = @$action;

        if(my $method = $sugar_meta->get_method($type)) {
            $target->${ \$method->body }(@args);
        }
        else {
            confess "'$type' is unknown to inject()";
        }
    }
}

sub _create_controller {
    my $controller = shift;
    my $app = Catalyst::Utils::class2appclass($controller);

    eval qq[
        package $controller;
        use CatalystX::Controller::Sugar;
        1;
    ];

    $app->setup_component($controller);
}

=head2 init_meta

See L<Moose::Exporter>.

=cut

sub init_meta {
    my $c   = shift;
    my %p   = @_;
    my $for = $p{'for_class'};

    Moose->init_meta(%p);
    CatalystX::Controller::Sugar->import;

    $for->meta->add_package_symbol('@ACTIONS', ());
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
