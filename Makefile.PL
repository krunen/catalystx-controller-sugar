use inc::Module::Install;

name     q(CatalystX-Controller-Sugar);
all_from q(lib/CatalystX/Controller/Sugar.pm);

requires q(Catalyst) => 5.80;
requires q(namespace::autoclean) => 0.09;
requires q(Data::Dumper) => 2.0;

test_requires q(Test::More) => 0;

auto_install;
WriteAll;
