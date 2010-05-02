use inc::Module::Install;

name q(CatalystX-Controller-Sugar);
all_from q(lib/CatalystX/Controller/Sugar.pm);

requires q(Catalyst::Runtime) => 5.80021;
requires q(Moose) => 0.94;
requires q(namespace::autoclean) => 0.09;
test_requires q(Data::Dumper) => 2.124;
test_requires q(Moose) => 0.94;
test_requires q(Test::More) => 0.92;

bugtracker 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=CatalystX-Controller-Sugar';
homepage 'http://search.cpan.org/dist/CatalystX-Controller-Sugar';
repository 'git://github.com/jhthorsen/catalystx-controller-sugar.git';

auto_install;
WriteAll;
