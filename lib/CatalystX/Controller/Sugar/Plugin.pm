package CatalystX::Controller::Sugar::Plugin;

=head1 NAME

CatalystX::Controller::Sugar::Plugin - Prepare a plugin, not a real controller

=head1 DESCRIPTION

This module prepare actions to be plugged in "somewhere" in another
controller. This is done, by using the L</inject()> method.

=head1 SYNOPSIS

 #= first... ==============================
 package My::Plugin;
 use CatalystX::Controller::Sugar::Plugin;
 # Same as L<CatalystX::Controller::Sugar>.
 1;

 #= then... ===============================
 package MyApp::Controller::Foo;
 My::Plugin->inject;
 1;

 #= or... =================================
 package MyApp;
 My::Plugin->inject("MyApp::Controller::Foo");
 1;

See L<EXTENDED SYNOPSIS> for how to include attributes.

=cut

use Moose;
use Moose::Exporter;
use namespace::autoclean ();
use CatalystX::Controller::Sugar ();
use Catalyst::Utils;
use Data::Dumper ();

our $SILENT = 0;
our $SYMBOL = '@ACTIONS';

Moose::Exporter->setup_import_methods(
    with_meta => [qw/ chain private /],
    as_is => [qw/ inject /],
    also => 'Moose',
);

=head1 EXPORTED FUNCTIONS

=head2 chain

Same as L<CatalystX::Controller::Sugar::chain()>, but will only prepare the
action to be injected in some other controller.

=cut

sub chain {
    my $meta = shift;
    my $action_list = $meta->get_package_symbol($SYMBOL);
    push @$action_list, [chain => @_];
}

=head2 private

Same as L<CatalystX::Controller::Sugar::private()>, but will only prepare the
action to be injected in some other controller.

=cut

sub private {
    my $meta = shift;
    my $action_list = $meta->get_package_symbol($SYMBOL);
    push @$action_list, [private => @_];
}

=head2 METHODS

=head2 inject

 $controller_obj = $class->inject;
 $controller_obj = $class->inject($target);

Will inject the prepared actions into C<$target> namespace or caller's
namespace by default. This will also inject attributes from the plugin
package, but will not override any existing attributes with the same name.

Also the C<$target> controller will be spawned, unless it already exists
in the component list.

=cut

sub inject {
    my $plugin = shift;
    my $target = shift || (caller(0))[0];
    my $plugin_meta = $plugin->meta;
    my $is_plugin;
    
    if(Class::MOP::is_class_loaded($target)) {
        if($target->meta->get_package_symbol($SYMBOL)) {
            $is_plugin = 1;
        }
    }

    if($is_plugin) {
        return _inject_to_plugin($plugin_meta, $target);
    }
    else {
        return _inject_to_controller($plugin_meta, $target);
    }
}

sub _inject_to_plugin {
    my $plugin_list = $_[0]->get_package_symbol($SYMBOL);
    my $target_list = $_[1]->meta->get_package_symbol($SYMBOL);

    _inject_attributes(@_);

    push @$target_list, @$plugin_list;

    return 1;
}

sub _inject_to_controller {
    my($plugin_meta, $target) = @_;
    my $sugar_meta = CatalystX::Controller::Sugar->meta;
    my $action_list = $plugin_meta->get_package_symbol($SYMBOL);
    my $app = Catalyst::Utils::class2appclass($target);
    my $target_meta;

    # inject new controller
    if(!blessed $target and !exists $app->components->{$target}) {
        eval qq[
            package $target;
            use CatalystX::Controller::Sugar;
            1;
        ];
        $app->components->{$target} = $app->setup_component($target);
    }

    $target_meta = $target->meta;

    # inject actions to controller
    for my $action (@$action_list) {
        my($type, @args) = @$action;

        if(my $method = $sugar_meta->get_method($type)) {
            $target_meta->${ \$method->body }(@args);
        }
        else {
            confess "'$type' is unknown to inject()";
        }
    }

    # inject moose attributes
    _inject_attributes($plugin_meta, $target_meta);

    return blessed $target ? $target : $app->components->{$target};
}

sub _inject_attributes {
    my($plugin_meta, $target_meta) = @_;

    for my $attr ($plugin_meta->get_attribute_list) {
        if($target_meta->get_attribute($attr)) {
            warn "Plugin attribute will not be installed, since an attribute is already defined" unless($SILENT);
        }
        else {
            $target_meta->add_attribute( $plugin_meta->get_attribute($attr) );
        }
    }
}

=head2 init_meta

See L<Moose::Exporter>.

=cut

sub init_meta {
    my $c = shift;
    my %options = @_;
    my $sugar_meta = CatalystX::Controller::Sugar->meta;
    my @export = qw/ c captured controller forward go req report res session stash /;
    my $meta;

    $meta = Moose->init_meta(%options) || $options{'for_class'}->meta;

    # add a variable where the plugin actions should be stored
    $meta->add_package_symbol($SYMBOL, []);

    # add functions from CatalystX::Controller::Sugar to make the
    # plugin module compile
    for my $symbol (map { "&$_" } @export) {
        $meta->add_package_symbol(
            $symbol => $sugar_meta->get_package_symbol($symbol)
        );
    }

    # must not be cleaned by namespace::autoclean
    $meta->add_method(inject => \&inject);

    namespace::autoclean->import(-cleanee => $options{'for_class'});

    return $meta;
}

=head1 EXTENDED SYNOPSIS

 package My::Plugin;
 use Moose; # IMPORT "has"
 use CatalystX::Controller::Sugar::Plugin;

 has foo => (
    is => 'rw',
    isa => 'Str',
    lazy => 1, # <-- IMPORTANT
    default => 'foo value'
 );

 chain '' => sub {
 };

 #...

 1;

Attributes with default values has to be lazy. (Not quite sure why though...)
All attributes defined in a plugin package, will also be injected into the
caller controller. They are cloned and not shared among the controller, if
it is injected into multiple controllers.

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
