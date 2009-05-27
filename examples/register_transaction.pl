#!/usr/bin/env perl 

use lib "../lib";
use Net::ThreeScale::Client;
use strict;

my $provider_key = "provider_key_here";
my $user_key     = "user_key_here";

my $client = Net::ThreeScale::Client->new(
	url          => 'http://server.3scale.net',
	provider_key => $provider_key,
);

my $response =
  $client->start( $user_key, usage => { upload_bandwidth => 12, hits => 1 } );

if ( $response->is_success() ) {
	print "successfully created transaction ", $response->transaction->id,
	" with contract ", $response->transaction->contract_name, " and verification key ",
	$response->transaction->provider_verification_key,"\n";
}
else {
	die( "failed to create transaction with error:",
		$response->error_code(), " : ", $response->error_message() );
}

my $conf_response = $client->confirm( $response->transaction );
if ( $conf_response->is_success ) {
	print "successfully confirmed transaction", $response->transaction->id;

}
else {
	die(
		"failed to confirm transaction with error:",
		$conf_response->error_code(),
		" : ", $conf_response->error_message()
	);
}
