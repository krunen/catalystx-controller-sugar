package CataTest::Controller::Sugar;

use CatalystX::Controller::Sugar;

__PACKAGE__->config->{'namespace'} = q();

chained "/" => "sugar/" => sub {
    my($self, $c) = @_;
    $c->res->body("chained sugar");
};

chained "/" => "ch" => sub {
    my($self, $c) = @_;
    $c->res->print("==> /ch");
};

chained "/ch" => "foo/" => sub {
    my($self, $c) = @_;
    $c->res->print(" ==> foo/");
};

chained "/ch" => "bar/" => sub {
    my($self, $c) = @_;
    $c->res->print(" ==> bar/");
};

private foo => sub {
    my($self, $c) = @_;
};

1;
