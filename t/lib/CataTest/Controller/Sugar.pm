package CataTest::Controller::Sugar;

use CatalystX::Controller::Sugar;

__PACKAGE__->config->{'namespace'} = q();

#chain sub { };

chain "/" => "ch" => [],  sub {
    res->print("==> /ch");
};

chain "/ch" => "foo" => sub {
    res->print(" ==> foo/");
};

chain "/ch" => "bar" => sub {
    res->print(" ==> bar/");
};

chain "/" => "http_method" => {
    post => sub { res->print("HTTP POST") },
    get  => sub { res->print("HTTP GET") },
};

chain "/" => "age" => ['age'], sub {
    res->print("age=" .captured('age'));
};

chain "/age" => "end" => 1 => sub {
    res->print(" => age=" .captured('age') ." => [@_]");
};

chain "/", "c" => sub {
    res->body(ref c);
};

chain "/", "ctrl" => sub {
    res->body(controller);
};

chain "global" => sub {
    res->body('chain($pathpart => sub{})');
};

private foo => sub {
    # ...
};

1;
