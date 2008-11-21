use strict;
use warnings;
use blib;
use Carp qw(cluck);
use lib "../lib";

use Test::More tests=>3;
use Net::ThreeScale::Client;

local $SIG{__WARN__} = sub { cluck @_; };

my $DEBUG = 1 if $ENV{MKS_DEBUG_TESTS};

my $client =  Net::ThreeScale::Client->new( provider_key => 'abc123');

my $r1 = <<EOXML;
<?xml version="1.0" encoding="utf-8" ?>
       <transaction>
        <id>42</id>
        <contract_name>pro</contract_name>
        <provider_verification_key>c43a3e00565d95c297f5ea502864</provider_verification_key>
       </transaction>
EOXML


my $transaction= $client->_parse_transaction_response($r1);
ok($transaction->id()  == 42);
ok($transaction->contract_name() eq 'pro');
ok($transaction->provider_verification_key() eq 'c43a3e00565d95c297f5ea502864');


