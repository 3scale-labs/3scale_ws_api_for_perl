package Net::ThreeScale::Client;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT_OK %EXPORT_TAGS %QUEUE @QUEUE $QUEUE);
use Exporter;
use Data::Dumper;
use Carp;

use XML::Parser;

use LWP::UserAgent;
use HTTP::Request;
use HTTP::Status;
use HTTP::Request::Common;

use Net::ThreeScale::Response;
use Net::ThreeScale::Transaction;
my $DEFAULT_USER_AGENT;

use constant {
	TS_RC_SUCCESS                => 'client.success',
	TS_RC_INVALID_KEY            => 'provider.invalid_key',
	TS_RC_INVALID_METRIC         => 'provider.invalid_metric',
	TS_RC_INVALID_TRANSACTION_ID => 'provider.invalid_transaction_id',
	TS_RC_EXCEEDED_LIMITS        => 'user.exceeded_limits',
	TS_RC_INVALID_USER_KEY       => 'user.invalid_key',
	TS_RC_INACTIVE_CONTRACT      =>'user.inactive_contract',
	TS_RC_INTERNAL_SERVER_ERROR           => 'system.other',
	TS_RC_UNKNOWN_ERROR          => 'client.unknown_error'
};

BEGIN {
	@ISA         = qw(Exporter);
	$VERSION     = "0.1.2";
	@EXPORT_OK   = qw();
	%EXPORT_TAGS = (
		'all' => \@EXPORT_OK,
		'ALL' => \@EXPORT_OK,
	);
	$DEFAULT_USER_AGENT = "threescale_perl_client/$VERSION";

}

sub new {
	my $class = shift;
	my $params = ( $#_ == 0 ) ? { %{ (shift) } } : {@_};

	my $url =
	  ( defined( $params->{url} ) ) ? $params->{url} : "http://3scale.net";
	my $agent_string =
	  ( defined( $params->{user_agent} ) )
	  ? $params->{user_agent}
	  : $DEFAULT_USER_AGENT;

	croak("provider_key is a required parameter")
	  unless defined( $params->{provider_key} );

	my $self = {};
	$self->{provider_key} = $params->{provider_key};
	$self->{url}          = $url;
	$self->{DEBUG}        = $params->{DEBUG};
	$self->{ua}           = LWP::UserAgent->new( agent => $agent_string );
	return bless $self, $class;
}

sub start {
	my $self     = shift;
	my $user_key = shift;
	my $p        = ( $#_ == 0 ) ? { %{ (shift) } } : {@_};
	die("user_key is a required parameter") unless defined($user_key);
	my $usage = ( exists( $p->{usage} ) ) ? $p->{usage} : {};
	die("usage must be a hash ref ") unless ref($usage) eq 'HASH';

	my %query = (
		provider_key => $self->{provider_key},
		user_key     => $user_key
	);

	while ( my ( $k, $v ) = each( %{$usage} ) ) {
		$query{ 'usage[' . $k . ']' } = $v;
	}

	my $url = $self->{url} . "/transactions.xml";

	my $request = HTTP::Request::Common::POST( $url, \%query );

	$self->_debug( "start> sending request: ", $request->as_string );
	my $response = $self->{ua}->request($request);

	$self->_debug( "start> got resposne : ", $response->as_string );

	if ( $response->is_success ) {
		my $transaction =
		  $self->_parse_transaction_response( $response->content() );
		return Net::ThreeScale::Response->new(
			error_code  => TS_RC_SUCCESS,
			success     => 1,
			transaction => $transaction
		);
	}
	else {
		return $self->_wrap_error($response);
	}
}

sub confirm {
	my $self        = shift;
	my $transaction = shift;
	my $p           = ( $#_ == 0 ) ? { %{ (shift) } } : {@_};
	die("transaction is a required parameter") unless defined($transaction);

	my $usage = ( exists( $p->{usage} ) ) ? $p->{usage} : {};
	die("usage must be a hash ref ") unless ref($usage) eq 'HASH';

	my $transaction_id;
	if ( ref($transaction) eq 'Net::ThreeScale::Transaction' ) {
		$transaction_id = $transaction->id;
	}
	else {
		$transaction_id = $transaction;
	}

	my $url =
	  $self->{url} . '/transactions/' . $transaction_id . '/confirm.xml';
	my %query = ( provider_key => $self->{provider_key} );
	while ( my ( $k, $v ) = each( %{$usage} ) ) {
		$query{ 'usage[' . $k . ']' } = $v;
	}
	my $request = HTTP::Request::Common::POST( $url, \%query );
	$self->_debug( "confirm> sending request: ", $request->as_string );
	my $response = $self->{ua}->request($request);
	$self->_debug( "confirm> got response: ", $response->as_string );
	if ( $response->is_success ) {
		my $ret_transaction;
		if ( ref($transaction) eq 'Net::ThreeScale::Transaction' ) {
			$ret_transaction = $transaction;
		}
		else {
			$ret_transaction =
			  new Net::ThreeScale::Transaction( id => $transaction_id );
		}
		return Net::ThreeScale::Response->new(
			transaction => $ret_transaction,
			success     => 1,
			error_code  => TS_RC_SUCCESS
		);
	}
	else {
		return $self->_wrap_error($response);
	}
}

sub cancel {
	my $self        = shift;
	my $transaction = shift;
	my $p           = ( $#_ == 0 ) ? { %{ (shift) } } : {@_};
	die("transaction is a required parameter") unless defined($transaction);

	my $usage = ( exists( $p->{usage} ) ) ? $p->{usage} : {};
	die("usage must be a hash ref ") unless ref($usage) eq 'HASH';

	my $transaction_id;
	if ( ref($transaction) eq 'Net::ThreeScale::Transaction' ) {
		$transaction_id = $transaction->id;
	}
	else {
		$transaction_id = $transaction;
	}

	my $url = $self->{url} . '/transactions/' . $transaction_id . '.xml';
	my %query = ( provider_key => $self->{provider_key} );
	while ( my ( $k, $v ) = each( %{$usage} ) ) {
		$query{ 'usage[' . $k . ']' } = $v;
	}

# use POST semantics for delete, and then change method name to make up for lack of delete in LWP
	my $request = HTTP::Request::Common::POST( $url, \%query );
	$request->method('DELETE');
	$self->_debug( "delete> sending request: ", $request->as_string );
	my $response = $self->{ua}->request($request);
	$self->_debug( "delete> got response: ", $response->as_string );
	if ( $response->is_success ) {
		my $ret_transaction;
		if ( ref($transaction) eq 'Net::ThreeScale::Transaction' ) {
			$ret_transaction = $transaction;
		}
		else {
			$ret_transaction =
			  new Net::ThreeScale::Transaction( id => $transaction_id );
		}
		return Net::ThreeScale::Response->new(
			transaction => $ret_transaction,
			success     => 1,
			error_code  => TS_RC_SUCCESS
		);
	}
	else {

		return $self->_wrap_error($response);

	}

}

#Wraps an HTTP::Response message into a Net::ThreeScale::Response error return value
sub _wrap_error {
	my $self = shift;
	my $res  = shift;
	my $error_code;
	my $message;
	eval { ( $error_code, $message ) = $self->_parse_errors( $res->content() ); };
	if ($@) {
		if ( $res->code == RC_INTERNAL_SERVER_ERROR ) {
			$error_code = TS_RC_INTERNAL_SERVER_ERROR;
			$message    = 'Internal server error';
		}
		else {
			$error_code = TS_RC_UNKNOWN_ERROR;
			$message    = 'unknown_error';
		}

	}

	return Net::ThreeScale::Response->new(
		success    => 0,
		error_code => $error_code,    #
		error_message      => $message
	);

}

# Parses an error document out of a response body
# If no sensible error messages are found in the response, insert the standard error value
sub _parse_errors {
	my $self = shift;
	my $body = shift;
	my $cur_error;
	my $in_error  = 0;
	my $errstring = undef;
	my $errcode   = TS_RC_UNKNOWN_ERROR;

	return undef if !defined($body);
	my $parser = new XML::Parser(
		Handlers => {
			Start => sub {
				my $expat   = shift;
				my $element = shift;
				my %atts    = @_;

				if ( $element eq 'error' ) {
					$in_error  = 1;
					$cur_error = "";
					if ( defined( $atts{id} ) ) {
						$errcode = $atts{id};
					}
				}
			},
			End => sub {
				if ( $_[1] eq 'error' ) {
					$errstring = $cur_error;
					$cur_error = undef;
					$in_error  = 0;
				}
			},
			Char => sub {
				if ($in_error) {
					$cur_error .= $_[1];
				}
			  }
		}
	);

	eval { $parser->parse($body); };

	return ( $errcode, $errstring );
}

sub _parse_transaction_response {
	my $self          = shift;
	my $response_body = shift;
	my $in_error      = 0;
	my $content       = undef;
	my $transaction_id;
	my $contract_name;
	my $provider_verification_key;
	my $parser = XML::Parser->new(
		Handlers => {
			Start => sub {
				undef($content);
			},
			End => sub {
				if ( $_[1] eq 'id' ) {
					$transaction_id = $content;
				}
				elsif ( $_[1] eq 'contract_name' ) {
					$contract_name = $content;
				}
				elsif ( $_[1] eq 'provider_verification_key' ) {
					$provider_verification_key = $content;
				}
				undef($content);
			},
			Char => sub {
				$content .= $_[1];
			  }
		}
	);
	$parser->parse($response_body);
	return Net::ThreeScale::Transaction->new(
		id                  => $transaction_id,
		contract_name       => $contract_name,
		provider_verification_key => $provider_verification_key
	);
}

sub _debug {
	my $self = shift;
	if ( $self->{DEBUG} ) {
		print STDERR "DBG:", @_, "\n";
	}

}
1;

=head1 NAME

Net::ThreeScale::Client - Client for 3Scale.com web API payments system

=head1 SYNOPSIS

 use Net::ThreeScale::Client;
 
 my $client = new Net::ThreeScale::Client(provider_key=>"my_assigned_provider_key", 
                                        url=>"http://3Scale.net");
 
 my $response =  $client->start( $user_key,
                                 usage => { storage => 12 });
 								 
 if($response->is_success){
	print "created transaction ", $response->transaction,"\"n";
	...
	my $conf_response = $client->confirm($response->transaction));
	if($conf_response->is_success){
		print STDERR "Confirmed transaction ",$transaction;
	}else{
		print STDERR "Confirming transaction failed with error ",
		              $response->error_code(),":",
		              $response->error_message(),"\n";
	}
 } else{
 	print STDERR "create transaction failed with error :", 
 			$response->error_message,"\n";
 	if($response->error_code == TS_RC_EXCEEDED_LIMITS){
 	 	print "Client has exceeded contract limits";
 	}else{	
 	 		...
 	}
 }

=head1 CONSTRUCTOR
 
 The class method new(...) creates a new 3Scale client object. This may 
 be used to conduct transactions with the 3Scale service. The object is 
 stateless and transactions may span multiple clients. The following 
 paramaters are recognised as arguments to new():

=over 4
 
=item provider_key 

(required) The provider key used to identify you with the 3Scale service

=item url 

(optional) The 3Scale service URL, usually this should be left to the 
default value 

=back

=head1 $response = $client->start($user_key,...)

Starts a new client transaction the call must include a user key (as 
a string), identifying the user for whom the transaction is starting. 
 
Returns a Net::ThreeScale::Respsonse object which indicates whether the 
transaction was successfully created including details of the new 
transaction or, indicates an error if one occured.  
 
The following arguments may also be passed: 

=over 4

=item  usage=>{metric=>value,...} 

(optional) The usage parameter should contain a  HASHref of  metric/value
pairs  describing  the estimated resource useage for this transaction. If 
this  parameter is not present then the actual usage must be reported 
when the transaction is completed using $client->confirm(...). 

=back


=head1 $response = $client->confirm($transaction,...)

Confirms a given transaction with some usage. The first argument must 
either be a Net::ThreeScale::Tranasaction object obtained from from a 
Net::ThreeScale::Response  object returned by  $client->start or a transaction
id. Optional arguments are as follows: 

=over 4

=item usage=>{metric=>value,...}

(optional) Indicates the actual resources used in this transaction. 
Should contain a HASHref of metric/value pairs (see $client->start(...)). 
The values specified here superscede any values passed to 
$client->start(..) . Usage information must be passed if no usage 
information was passed to $client->start for this transaction. 


=back


=head1  $response = $client->cancel($transaction)

Cancels a given transaction. $transaction must be either a 
Net::ThreeScale::Transaction object obtained from from a Net::ThreeScale::Response 
object returned by  $client->start or a  transaction id (as a string). 

Returns a Net::ThreeScale::Respsonse object which indicates whether the 
transaction was successfully created including details of the new 
transaction or, indicates an error if one occured.  

=head1 EXPORTS / ERROR CODES

The following constants are exported and correspond to error codes 
which may appear in calls to Net::ThreeScale::Response::error_code

=over 4

=item TS_RC_SUCCESS

The operation completed successfully 

=item TS_RC_INVALID_KEY

The  passed provider key was invalid

=item TS_RC_INVALID_METRIC

One or more of the metrics passed did not correspond to a 
metric found in the specified contract

=item TS_RC_INVALID_TRANSACTION_ID

The transaction ID was invalid or the transaction has expired

=item TS_RC_EXCEEDED_LIMITS 

The user has exceeded one or more of the limits in the contract 

=item TS_RC_INVALID_USER_KEY

The user key was not found or was invalid

=item TS_RC_INACTIVE_CONTRACT

The specified contract is not active

=item TS_RC_INTERNAL_SERVER_ERROR           

An unspecified internal server error occured	

=item TS_RC_UNKNOWN_ERROR 

Some other unspecified error has occured - this may be due to connectivity issues. 

=back

=head1 SEE ALSO 

=over 4

=item  Net::ThreeScale::Response

Contains details of response contnet and values. 
 
=item Net::ThreeScale::Transaction

Gives details of information about transactions

=back

=head1 AUTHOR 

(c) Owen Cliffe 2008