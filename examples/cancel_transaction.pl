#!/usr/bin/env perl 

use lib "../lib";
use Net::ThreeScale::Client;
use strict;

my $provider_key = "provider key here";
my $user_key     = "user key here"; 


my $client = Net::ThreeScale::Client->new( url=>'http://beta.3scale.net',provider_key => $provider_key );

my $response = $client->start( $user_key, usage => {  upload_bandwidth => 12 } );
if ( $response->is_success() ) {
	print "successfully created transaction ", $response->transaction->id ,"\n";
	print " with contract "   ,$response->transaction->contract_name,"\n";
}
else {
	die( "failed to create transaction with error:", $response->error_code," " ,$response->error_message );
}

my $conf_response = $client->cancel( $response->transaction );
if ( $conf_response->is_success ) {
	print "successfully cancelled transaction ", $response->transaction,"\n";

}
else {
	die( "failed to cancel transaction with error:", $conf_response->error );
}
