#!perl

use strict;
use warnings;
use lib qw(lib t/lib);
use Catalyst::Test 'CataTest';
use Test::More tests => 5;
use CataTest::FooPlugin;

action_ok('/');
content_like('/plugin_endpoint', qr{default page}, 'plugin endpoint does not exist');
content_like('/plugin_private_data', qr{default page}, 'plugin endpoint does not exist');

CataTest::FooPlugin->inject('CataTest::Controller::Root');

content_like(
    '/plugin_endpoint',
    qr{plugin endpoint body},
    'plugin endpoint'
);
content_like(
    '/plugin_private_data',
    qr{42 is the answer},
    'plugin endpoint'
);
