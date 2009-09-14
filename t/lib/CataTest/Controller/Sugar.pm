package CataTest::Controller::Sugar;

use CatalystX::Controller::Sugar;

# NOTE: #. = refers to the number before syntax example for
# chain() in lib/CatalystX/Controller/Sugar.pm

# 1. chain: /sugar
chain sub {
};

# 2. endpoint: /sugar/context/[*]
chain "context" => sub {
    res->body(ref c);
};

# 3. endpoint: /sugar/ctrl
chain "ctrl" => 0 => sub {
    res->body(controller);
};

# 4. chain: /sugar/ch
chain "ch" => [],  sub {
    res->print("==> /ch");
};

# 5. endpoint: /sugar/ch/foo/[*]
chain "ch" => "foo" => sub {
    res->print(" ==> foo/");
};

# 6. endpoint: /sugar/ch/bar
chain "ch" => "bar" => 0 => sub {
    res->print(" ==> bar/");
};

# 4. chain: /sugar/user/[1]
chain "user" => ['name'], sub {
    res->print("user=" .captured('name'));
};

# 6. endpoint: sugar/user/[1]/action/[1]
chain "user:1" => "action" => 1 => sub {
    res->print(" => user=" .captured('name') ." => [@_]");
};

1;
