package CataTest::FooPlugin;

use CatalystX::Controller::Sugar::Plugin;

chain plugin_endpoint => sub {
    res->body('plugin endpoint body');
};

chain plugin_private_data => sub {
    res->body( stash('plugin_private_data') );
};

private plugin_private => sub {
    #stash plugin_private_data => '42 is the answer';
};

1;
