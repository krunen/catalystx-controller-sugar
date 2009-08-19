package CataTest::Controller::Sugar;

use CatalystX::Controller::Sugar;

# /sugar
chain sub {
};

# /sugar/ch
chain "ch" => [],  sub {
    res->print("==> /ch");
};

# /sugar/ch/foo
chain "ch" => "foo" => sub {
    res->print(" ==> foo/");
};

# /sugar/ch/bar
chain "ch" => "bar" => sub {
    res->print(" ==> bar/");
};

# /sugar/user
chain "user" => ['name'], sub {
    res->print("user=" .captured('name'));
};

# /sugar/user/*/action/...
chain "user" => "action" => 1 => sub {
    res->print(" => user=" .captured('name') ." => [@_]");
};

# /sugar/context
chain "context" => sub {
    res->body(ref c);
};

# /sugar/ctrl
chain "ctrl" => sub {
    res->body(controller);
};

1;
