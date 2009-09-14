package CataTest::Controller::Sugar::Foo;

use CatalystX::Controller::Sugar;

# NOTE: #. = refers to the number before syntax example for
# chain() in lib/CatalystX/Controller/Sugar.pm

# 1. chain: /sugar/foo
chain sub {
};

chain action_a => 0 => sub {
    res->print("action_a");
};

1;
