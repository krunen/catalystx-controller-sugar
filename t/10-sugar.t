#!perl

use strict;
use warnings;
use lib q(lib);
use Test::More tests => 12;

BEGIN {
    use lib q(t/lib);
    use_ok("Catalyst::Test", "CataTest");
}

ok(
    request("/")->is_success,
    "index page received"
);
is(
    request("/get_stash")->content,
    q(123),
    "/get_stash"
);
is(
    request("/dump_stash")->content,
    q($VAR1 = {'bar' => [1,2,3],'foo' => 42};),
    "/dump_stash"
);
is(
    request("/ch/foo")->content,
    "==> /ch ==> foo/",
    "/ch/foo",
);
is(
    request("/ch/bar")->content,
    "==> /ch ==> bar/",
    "/ch/bar",
);
is(
    request("/http_method")->content,
    "HTTP GET",
    "/ch/http_method => get",
);
is(
    request("/age/42/end/foo")->content,
    "age=42 => age=42 => [foo]",
    "/age/42/end/foo named captures",
);
is(
    request("/ctrl")->content,
    "CataTest::Controller::Sugar",
    "controller() returns controller class",
);
is(
    request("/c")->content,
    "CataTest",
    "c() returns context object",
);
is(
    request('/global')->content,
    'chain($pathpart => sub{})',
    'chained $path_part => sub {}',
);
is(
    request('/test_root')->content,
    'exists=yes',
    'root chain is defined',
);
