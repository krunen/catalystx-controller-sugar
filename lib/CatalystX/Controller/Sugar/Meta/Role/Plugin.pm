package CatalystX::Controller::Sugar::Meta::Role::Plugin;

=head1 NAME

CatalystX::Controller::Sugar::Meta::Role::Plugin

=cut

use Moose::Role;

with 'CatalystX::Controller::Sugar::Meta::Role' => {
    -excludes => [qw/ add_chain_action add_private_action /],
};

=head1 METHODS

=head2 add_chain_action

=cut

sub add_chain_action {
    my $meta = shift;
    my $name = shift;

    $meta->_add_chain_action($name => [@_]);
}

=head2 add_private_action

=cut

sub add_private_action {
    my $meta = shift;
    my $name = shift;

    $meta->_add_private_action($name => [@_]);
}

=head1 AUTHOR

=head1 LICENSE

See L<CatalystX::Controller::Sugar>.

=cut

1;
