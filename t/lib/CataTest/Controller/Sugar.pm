package CataTest::Controller::Sugar;

use CatalystX::Controller::Sugar;

__PACKAGE__->config->{'namespace'} = q();

chained "/" => "sugar" => sub {
    my($self, $c) = @_;
    $c->res->body("chained sugar");
};

chained "/" => "ch" => [],  sub {
    res->print("==> /ch");
};

chained "/ch" => "foo" => sub {
    res->print(" ==> foo/");
};

chained "/ch" => "bar" => sub {
    res->print(" ==> bar/");
};

chained "/" => "http_method" => {
    post => sub { res->print("HTTP POST") },
    get  => sub { res->print("HTTP GET") },
};

chained "/" => "age" => ['age'], sub {
    res->print("age=" .captured('age'));
};

chained "/age" => "end" => 1 => sub {
    res->print(" => age=" .captured('age') ." => [@_]");
};

chained "/", "c" => sub {
    res->body(ref c);
};

chained "/", "ctrl" => sub {
    res->body(controller);
};

private foo => sub {
    # ...
};

1;
