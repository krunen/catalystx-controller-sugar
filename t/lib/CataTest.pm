package CataTest;

use Moose;
use CataTest::FooPlugin;
use Catalyst; # qw/-Debug/;

# works:
# not really a test, but will die in $VERSION<=0.04
after setup_components => sub {
    CataTest::FooPlugin->inject('CataTest::Controller::NON_EXISTENT');
};

__PACKAGE__->config( name => 'CataTest', root => '/some/dir' );
__PACKAGE__->setup;

1;
