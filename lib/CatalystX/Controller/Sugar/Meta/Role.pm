package CatalystX::Controller::Sugar::Meta::Role;

=head1 NAME

CatalystX::Controller::Sugar::Meta::Role

=cut

use Moose::Role;

=head1 ATTRIBUTES

=head2 chain_root_name

 $str = $self->chain_root_name;

Default value is "root". It is used for actions like this:

 chain sub { ... };

=cut

has chain_root_name => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { $CatalystX::Controller::Sugar::ROOT }, # lazy
);

=head2 chain_default_name

 $str = $self->chain_default_name;

Default value is "default". It is used for actions like this:

 chain '' => sub { ... };

=cut

has chain_default_name => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { $CatalystX::Controller::Sugar::DEFAULT }, # lazy
);

=head2 chain_action_map

 $meta->add_chain_action($str => @args);
 $bool = $meta->has_chain_action($str);
 $method_obj = $meta->get_chain_action($str);
 @str = $meta->get_chain_action_list;

=cut

has chain_action_map => (
    is => 'ro',
    isa => 'HashRef',
    traits => ['Hash'],
    default => sub { {} },
    handles => {
        _add_chain_action => 'set',
        has_chain_action => 'exists',
        get_chain_action => 'get',
        get_chain_action_list => 'keys',
    },
);

=head2 private_action_map

 $meta->add_private_action($str => $code_ref);
 $bool = $meta->has_private_action($str);
 $method_obj = $meta->get_private_action($str);
 @str = $meta->get_private_action_list;

=cut

has private_action_map => (
    is => 'ro',
    isa => 'HashRef',
    traits => ['Hash'],
    default => sub { {} },
    handles => {
        _add_private_action => 'set',
        has_private_action => 'exists',
        get_private_action => 'get',
        get_private_action_list => 'keys',
    },
);

=head1 METHODS

=head2 add_chain_action

 $meta->add_chain_action(@args);

See L<CatalystX::Controller::Sugar::chain()>.

=cut

sub add_chain_action {
    my $meta = shift;
    my $code = pop;
    my @args = @_;
    my $class = $meta->name;
    my $root_name = $meta->chain_root_name;
    my $default_name = $meta->chain_default_name;
    my($c, $name, $ns, $attrs, $path, $action);

    $c     = Catalyst::Utils::class2appclass($class);
    $ns    = $class->action_namespace($c) || q();
    $attrs = $meta->_setup_chain_attrs($ns, @args);

    $path  =  $attrs->{'Chained'}[0];
    $path  =~ s,$root_name$,,;
    $path .=  $attrs->{'PathPart'}[0];

    if($path ne "/$ns") {
        $name = (split "/", $attrs->{'PathPart'}[0])[-1];
    }
    elsif($c->dispatcher->get_action($root_name, $ns)) {
        $name = $default_name;
    }
    else {
        $name = $root_name;
    }

    # add captures to name
    if(@{ $attrs->{'capture_names'} }) {
        $name ||= q();
        $name  .= ":" .int @{ $attrs->{'capture_names'} };
    }

    # set default name
    # is this correct?
    elsif(!$name) {
        $name = $default_name;
    }

    $action = $class->create_action(
                  name => $name,
                  code => $meta->_create_chain_code($name, $code),
                  reverse => $ns ? "$ns/$name" : $name,
                  namespace => $ns,
                  class => $class,
                  attributes => $attrs,
              );

    $meta->_add_chain_action($name => [@args, $code]);
    $c->dispatcher->register($c, $action);
}

sub _setup_chain_attrs {
    my $meta = shift;
    my $ns = shift;
    my $attrs = {};
    my $root_name = $meta->chain_root_name;

    if(@_) { # chain ..., sub {};
        if(ref $_[-1] eq 'ARRAY') { # chain ..., [...], sub {}
            $attrs->{'CaptureArgs'} = [int @{ $_[-1] }];
            $attrs->{'capture_names'} = pop @_;
        }
        elsif(defined $_[-1] and $_[-1] =~ /^(\d+)$/) { # chain ..., $int, sub {}
            $attrs->{'Args'} = [pop @_];
        }

        if(defined $_[-1]) { # chain ..., $str, $any, sub {};
            $attrs->{'PathPart'} = [pop @_];
        }
        else {
            my $args = join ", ", @_;
            confess "Invalid arguments: chain($args)";
        }

        if(defined $_[-1]) { # chain $str, ... sub {};
            my $with = pop @_;
            $attrs->{'Chained'} = [ $with =~ m,^/, ? $with
                                  : $ns            ? "/$ns/$with"
                                  :                  "/$with"
                                  ];
        }
        else {
            $attrs->{'Chained'} = [$ns ? "/$ns/$root_name" : "/$root_name"];
        }
    }
    else { # chain sub {};
        my($parent, $this) = $ns =~ m[ ^ (.*)/(\w+) $ ]x;
        my $chained = $parent ? "/$parent/$root_name"
                    : $ns     ? "/$root_name"
                    :           "/";

        $attrs->{'Chained'}     = [$chained];
        $attrs->{'PathPart'}    = [$this || $ns];
        $attrs->{'CaptureArgs'} = [0];
    }

    $attrs->{'Args'} = [] unless($attrs->{'CaptureArgs'});
    $attrs->{'capture_names'} ||= [];

    return $attrs;
}

sub _create_chain_code {
    my($meta, $name, $code) = @_;
    my $sub;

    if(ref $code eq 'HASH') {
        for my $method (keys %$code) {
            $meta->add_method("$name\_$method" => $code->{$method});
        }

        $sub = sub {
            my($self, $c) = (shift, shift);
            my $method = lc $c->req->method;

            local $CatalystX::Controller::Sugar::SELF = $self;
            local $CatalystX::Controller::Sugar::CONTEXT = $c;
            local $CatalystX::Controller::Sugar::RES = $c->res;
            local $CatalystX::Controller::Sugar::REQ = $c->req;
            local %CatalystX::Controller::Sugar::CAPTURED = _setup_captured($c);

            if(my $code = $meta->get_method("$name\_$method")) {
                return $code->body->(@_);
            }
            elsif($code = $meta->get_method("$name\_default")) {
                return $code->body->(@_);
            }
            else {
                $c->res->status(404);
            }
        };
    }
    else {
        $meta->add_method($name => $code);

        $sub = sub {
            my($self, $c) = (shift, shift);

            local $CatalystX::Controller::Sugar::SELF = $self;
            local $CatalystX::Controller::Sugar::CONTEXT = $c;
            local $CatalystX::Controller::Sugar::RES = $c->res;
            local $CatalystX::Controller::Sugar::REQ = $c->req;
            local %CatalystX::Controller::Sugar::CAPTURED = _setup_captured($c);

            return $meta->get_method($name)->body->(@_);
        };
    }

    return $sub;
}

sub _setup_captured {
    my $c = $_[0];
    my @names;

    for my $action (@{ $c->action->chain }) {
        push @names, @{ $action->attributes->{'capture_names'} };
    }

    return map { shift(@names), $_ } @{ $c->req->captures };
}

=head2 add_private_action

 $meta->add_private_action(@args);

See L<CatalystX::Controller::Sugar::private()>.

=cut

sub add_private_action {
    my $meta = shift;
    my $name = shift;
    my $code = shift;
    my $class = $meta->name;
    my($c, $ns, $private_code);
 
    $c = Catalyst::Utils::class2appclass($class);
    $ns = $class->action_namespace($c);

    $private_code = sub {
        my($self, $c) = (shift, shift);

        local $CatalystX::Controller::Sugar::SELF    = $self;
        local $CatalystX::Controller::Sugar::CONTEXT = $c;
        local $CatalystX::Controller::Sugar::RES     = $c->res;
        local $CatalystX::Controller::Sugar::REQ     = $c->req;

        return $meta->get_method($name)->body->(@_);
    };

    $meta->_add_private_action($name => [@_]);
    $meta->add_method($name => $code);

    $c->dispatcher->register($c,
        $class->create_action(
            name => $name,
            code => $private_code,
            reverse => $ns ? "$ns/$name" : $name,
            namespace => $ns,
            class => $class,
            attributes => { Private => [] },
        )
    );
}

=head1 AUTHOR

=head1 LICENSE

See L<CatalystX::Controller::Sugar>.

=cut

1;
