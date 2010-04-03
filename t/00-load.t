#!/usr/bin/perl
use lib qw(lib);
use Test::More;
plan tests => 2;
use_ok('CatalystX::Controller::Sugar');
use_ok('CatalystX::Controller::Sugar::Plugin');
