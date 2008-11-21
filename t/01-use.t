use strict;
use warnings;
use blib;
use Carp qw(cluck);

use Test::More  tests=>3;

use_ok('Net::ThreeScale::Client');
use_ok('Net::ThreeScale::Response');
use_ok('Net::ThreeScale::Transaction');
