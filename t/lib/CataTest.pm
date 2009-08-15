package CataTest;

use Moose;
use Catalyst; # qw/-Debug/;

__PACKAGE__->config( name => 'CataTest', root => '/some/dir' );
__PACKAGE__->setup;

1;
