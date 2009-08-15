package CataTest::Controller::Sugar;

use CatalystX::Controller::Sugar;

__PACKAGE__->config->{'namespace'} = q();

chained "/" => "sugar/" => sub {
    my($self, $c) = @_;
    $c->res->body("chained sugar");
};

chained "/" => "ch" => sub {
    res->print("==> /ch");
};

chained "/ch" => "foo/" => sub {
    res->print(" ==> foo/");
};

chained "/ch" => "bar/" => sub {
    res->print(" ==> bar/");
};

chained "/" => "http_method/" => {
    post => sub { res->print("HTTP POST") },
    get  => sub { res->print("HTTP GET") },
};

private foo => sub {
    # ...
};

1;
