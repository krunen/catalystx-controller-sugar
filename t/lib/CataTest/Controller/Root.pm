package CataTest::Controller::Root;

use Data::Dumper;
use CatalystX::Controller::Sugar;

__PACKAGE__->config->{'namespace'} = q();

sub default :Private  {
    my($self, $c) = @_;
    $c->res->body("default page");
}

sub get_stash :Chained("/") PathPart Args(0) {
    my($self, $c) = @_;
    stash foo => 123;
    $c->res->body( stash 'foo' );
}

sub dump_stash :Chained("/") PathPart Args(0) {
    my($self, $c) = @_;
    stash foo => 42;
    stash bar => [1,2,3];
    $Data::Dumper::Indent = 0;
    $c->res->body( Dumper $c->stash );
}

sub end :Local {
    my($self, $c) = @_;
}

1;
