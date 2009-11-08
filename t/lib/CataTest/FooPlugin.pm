package CataTest::FooPlugin;

use Moose;
use CatalystX::Controller::Sugar::Plugin;

has body_text => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => 'plugin endpoint body',
);

chain plugin_endpoint => sub {
    res->body( controller->body_text );
};

chain plugin_private_data => sub {
    forward 'plugin_private';
    res->body( stash('plugin_private_data') );
};

private plugin_private => sub {
    stash plugin_private_data => '42 is the answer';
};

1;
