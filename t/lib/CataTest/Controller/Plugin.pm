package CataTest::Controller::Plugin;

use Data::Dumper;
use CataTest::FooPlugin;
use CatalystX::Controller::Sugar;

# anchor for FooPlugin actions
chain sub {};

CataTest::FooPlugin->inject;

1;
