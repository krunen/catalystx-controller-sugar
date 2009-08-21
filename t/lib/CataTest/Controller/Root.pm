package CataTest::Controller::Root;

use Data::Dumper;
use CatalystX::Controller::Sugar;

__PACKAGE__->config->{'namespace'} = q();

# private /rp

private rp => sub {
    return "private method is called";
};

# private: /end
# called after chain action has run
private end => sub {
    # ...
};

# NOTE: #. = refers to the number before syntax example for
# chain() in lib/CatalystX/Controller/Sugar.pm

# 1. chain: /
chain sub {
    stash root_is_set => 'yes';
};

# 2. endpoint: /[*]
chain "" => sub {
    res->body( @_ ? "default page (@_)" : "index page" );
};

# 2. endpoint: /test_private/[*]
chain "test_private" => sub {
    res->body( forward "/rp" );
};

# 2. endpoint: /test_body/[*]
chain test_root => sub {
    res->body( "exists=" .(stash('root_is_set') || 'no') );
};

# 2. endpoint: /get_stash/[*]
chain get_stash => sub {
    stash foo => 123;
    res->body( stash 'foo' );
};

# 2. endpoint: /dump_stash/[*]
chain dump_stash => sub {
    stash foo => 42;
    stash bar => [1,2,3];
    $Data::Dumper::Indent = 0;
    res->body( Dumper c->stash );
};

# 2. endpoint: /http_method/[*]
chain "http_method" => {
    post => sub { res->print("HTTP POST") },
    get  => sub { res->print("HTTP GET") },
};

# 5. /out/of/ns/[*]
chain "/" => "out/of/ns" => sub {
    res->print("outside namespace");
};

1;
