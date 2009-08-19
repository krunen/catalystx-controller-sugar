package CataTest::Controller::Root;

use Data::Dumper;
use CatalystX::Controller::Sugar;

__PACKAGE__->config->{'namespace'} = q();

# /
chain sub {
    stash root_is_set => 'yes';
};

# /
chain "" => sub {
    res->body("index page!");
};

# /global
chain "global" => sub {
    res->body('chain($pathpart => sub{})');
};

# /test_body
chain test_root => sub {
    res->body( "exists=" .(stash('root_is_set') || 'no') );
};

# /get_stash
chain get_stash => sub {
    stash foo => 123;
    res->body( stash 'foo' );
};

# /dump_stash
chain dump_stash => sub {
    stash foo => 42;
    stash bar => [1,2,3];
    $Data::Dumper::Indent = 0;
    res->body( Dumper c->stash );
};

# /http_method
chain "http_method" => {
    post => sub { res->print("HTTP POST") },
    get  => sub { res->print("HTTP GET") },
};

private default => sub {
    res->body("default page");
};

private end => sub {
};

1;
