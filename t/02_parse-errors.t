use strict;
use warnings;
use blib;
use Carp qw(cluck);

use Test::More  tests=>6;
use lib "../lib";
use Net::ThreeScale::Client;


local $SIG{__WARN__} = sub { cluck @_; };

my $DEBUG = 1 if $ENV{MKS_DEBUG_TESTS};

my $client = Net::ThreeScale::Client->new( url => 'server.3scale.net', provider_key => '3scale-abc123' );
ok(defined($client));
isa_ok($client,'Net::ThreeScale::Client');

my $r1 = <<EOXML;
<?xml version="1.0" encoding="utf-8" ?>
<error id="test.error">An error has occured</error>
</errors>
EOXML


my ($errcode,$error)= $client->_parse_errors($r1);


ok(defined($error) && $error eq 'An error has occured');
ok(defined($errcode)&& $errcode eq 'test.error');

my $r2 = <<EOXML;
<?xml version="1.0" encoding="utf-8" ?>
<errors>
1awaerror>An error has occured</error>
EOXML


($errcode,$error)= $client->_parse_errors($r2);
ok(!defined($error));
ok($errcode eq Net::ThreeScale::Client::TS_RC_UNKNOWN_ERROR);
