#!perl

use strict;
use warnings;
use lib qw(lib t/lib);
use Catalyst::Test 'CataTest';
use Test::More tests => 9;
use CataTest::FooPlugin;

action_ok('/', "CataTest set up");
content_like('/plugin_endpoint', qr{default page}, 'plugin endpoint does not exist');
content_like('/plugin_private_data', qr{default page}, 'plugin private data does not exist');

# prepared inject
content_like(
    '/plugin/plugin_endpoint',
    qr{^plugin endpoint body},
    'plugin endpoint injected into Plugin'
);
content_like(
    '/plugin/plugin_private_data',
    qr{^42 is the answer},
    'plugin private data injected into Plugin'
);

# before inject
content_like(
    '/plugin_endpoint',
    qr{^default page},
    'plugin endpoint is not injected into Root'
);
content_like(
    '/plugin_private_data',
    qr{^default page},
    'plugin private data is not injected Root'
);

CataTest::FooPlugin->inject('CataTest::Controller::Root');

# after inject
content_like(
    '/plugin_endpoint',
    qr{^plugin endpoint body},
    'plugin endpoint injected into Root'
);
content_like(
    '/plugin_private_data',
    qr{^42 is the answer},
    'plugin private data injected Root'
);


