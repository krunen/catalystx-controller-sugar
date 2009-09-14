package CataTest::Controller::Sugar::Foo;

use CatalystX::Controller::Sugar;

# NOTE: #. = refers to the number before syntax example for
# chain() in lib/CatalystX/Controller/Sugar.pm

# 1. chain: /sugar/foo
chain sub {
};

# 2. endpoint /sugar/foo/action_a
chain action_a => 0 => sub {
    res->print("action_a");
};

# 3. default /sugar/foo/*
chain '' => sub {
    res->print("default foo");
};

# 4. capture /sugar/foo/[c1]/
chain '' => [qw/c1 c2/] => sub {
    res->print("captured c1");
};

# 5. endpoint /sugar/foo/[c1]/*
chain ':2' => 'capture_end' => sub {
    res->print(", capture foo endpoint");
};

1;
