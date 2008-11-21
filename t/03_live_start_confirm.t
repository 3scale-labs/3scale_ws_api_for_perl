use strict;
use warnings;
use blib;
use Carp qw(cluck);
use lib "../lib";

use Test::More tests=>1;
use Net::ThreeScale::Client;

local $SIG{__WARN__} = sub { cluck @_; };

my $DEBUG = 1 if $ENV{MKS_DEBUG_TESTS};

my $client =  Net::ThreeScale::Client->new( url=>'http://beta.3Scale.net',provider_key => 'abc123');


my $response = $client->start('asdasdas',usage=>{foo=>'bar',bob=>'baz'});
my $conf_response = $client->confirm('123456');
my $del_response = $client->cancel('123456');

ok(defined($response));
