#!/usr/bin/perl
use lib qw(lib);
use Test::More;
eval 'use Test::Pod::Coverage' or plan skip_all => 'Test::Pod::Coverage required';
all_pod_coverage_ok();
