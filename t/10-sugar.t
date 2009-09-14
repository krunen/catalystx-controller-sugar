#!perl

use strict;
use warnings;
use lib qw(lib t/lib);
use Catalyst::Test 'CataTest';
use Test::More tests => 16;

is(
    request("/foo-bar-default")->content,
    "default page (foo-bar-default)",
    "default page defined",
);
is(
    request("/")->content,
    "index page",
    "index page defined",
);
is(
    request('/test_root')->content,
    'exists=yes',
    'root chain is defined',
);
is(
    request('/test_private')->content,
    'private method is called',
    '/test_private',
);
is(
    request('/out/of/ns')->content,
    'outside namespace',
    'outside namespace',
);
is(
    request("/get_stash")->content,
    q(123),
    "/get_stash"
);
is(
    request("/dump_stash")->content,
    q($VAR1 = {'bar' => [1,2,3],'foo' => 42,'root_is_set' => 'yes'};),
    "/dump_stash"
);
is(
    request("/sugar/ch/foo")->content,
    "==> /ch ==> foo/",
    "/ch/foo",
);
is(
    request("/sugar/ch/bar")->content,
    "==> /ch ==> bar/",
    "/ch/bar",
);
is(
    request("/sugar/user/doe/action/edit")->content,
    "user=doe => user=doe => [edit]",
    "/user/[name]/action/... named captures",
);
like(
    request("/sugar/ctrl")->content,
    qr{^CataTest::Controller::Sugar},
    "controller() returns controller class",
);
is(
    request("/sugar/context")->content,
    "CataTest",
    "c() returns context object",
);
is(
    request("/http_method")->content,
    "HTTP GET",
    "multi method => get",
);
is(
    request("/sugar/foo/action_a")->content,
    "action_a",
    "parent controller inherit root action",
);
is(
    request("/sugar/foo/dafault_foo")->content,
    "default foo",
    "default action set for Foo",
);
is(
    request("/sugar/foo/42/24/capture_end")->content,
    "captured c1, capture foo endpoint",
    "capture action set up for Foo",
);
