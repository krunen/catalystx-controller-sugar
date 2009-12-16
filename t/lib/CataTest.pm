package CataTest;

use Moose;
use CataTest::FooPlugin;
use Catalyst; # qw/-Debug/;

# works:
#after setup_components => sub {
#    CataTest::FooPlugin->inject('CataTest::Controller::NON_EXISTENT');
#};

__PACKAGE__->config( name => 'CataTest', root => '/some/dir' );
__PACKAGE__->setup;

1;
