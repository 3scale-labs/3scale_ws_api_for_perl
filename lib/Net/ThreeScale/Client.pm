package Net::ThreeScale::Client;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT_OK %EXPORT_TAGS %QUEUE @QUEUE $QUEUE);
use Exporter;
use Data::Dumper;
use Carp;

use XML::Parser;
use XML::Simple;

use LWP::UserAgent;
use URI::Escape;
use HTTP::Request;
use HTTP::Status;
use HTTP::Request::Common;

use Net::ThreeScale::Response;
my $DEFAULT_USER_AGENT;

use constant {
	TS_RC_SUCCESS                => 'client.success',
	TS_RC_AUTHORIZE_FAILED       => 'provider_key_invalid',
	TS_RC_UNKNOWN_ERROR          => 'client.unknown_error'
};

BEGIN {
	@ISA         = qw(Exporter);
	$VERSION     = "2.0.2";
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

	my $agent_string =
	  ( defined( $params->{user_agent} ) )
	  ? $params->{user_agent}
	  : $DEFAULT_USER_AGENT;

	croak("provider_key is a required parameter")
		unless defined( $params->{provider_key} );

	$params->{url} = 'http://su1.3scale.net'
		unless(defined($params->{url}));

	my $self = {};
	$self->{provider_key} = $params->{provider_key};
	$self->{url}          = $params->{url};
	$self->{DEBUG}        = $params->{DEBUG};
	$self->{ua}           = LWP::UserAgent->new( agent => $agent_string );

	return bless $self, $class;
}

sub authorize {
	my $self     = shift;
	my $p        = ( $#_ == 0 ) ? { %{ (shift) } } : {@_};

	die("app_id is required") unless defined($p->{app_id});

	my %query = (
		provider_key => $self->{provider_key},
	);

	while (my ($k, $v) = each(%{$p})) {
		$query{$k} = $v;
	}

	my $url = URI->new($self->{url} . "/transactions/authorize.xml");

	$url->query_form(%query);

	my $request = HTTP::Request::Common::GET($url);

	$self->_debug( "start> sending request: ", $request->as_string );
	my $response = $self->{ua}->request($request);

	$self->_debug( "start> got response : ", $response->as_string );

	if ( not ( $response->is_success || $response->status_line =~ /409/)) {
		return $self->_wrap_error($response);
	}

	my $data = $self->_parse_authorize_response( $response->content() );
	
	if ($data->{authorized} ne "true") {
		my $reason = $data->{reason};

		$self->_debug("authorization failed: $reason");

		return Net::ThreeScale::Response->new(
			success            => 0,
			error_code         => TS_RC_UNKNOWN_ERROR,
			error_message      => $reason
		)
	}

	$self->_debug( "success" );

	return Net::ThreeScale::Response->new(
		error_code  => TS_RC_SUCCESS,
		success     => 1,
		usage_reports => \@{$data->{usage_reports}->{usage_report}}
	);
}

sub report {
	my $self     = shift;
	my $p        = ( $#_ == 0 ) ? { %{ (shift) } } : {@_};

	die("transactions is a required parameter") unless defined($p->{transactions});
	die("transactions parameter must be a list")
		unless (ref($p->{transactions}) eq "ARRAY");

	my %query = (
		provider_key => $self->{provider_key},
	);

	while (my ($k, $v) = each(%{$p})) {
		if ($k eq "transactions") {
			next;
		}

		$query{$k} = $v;
	}

	my $content = "";

	while (my ($k, $v) = each(%query)) {
		if (length($content)) {
				$content .= "&\r\n";
		}

		$content .= "$k=" . uri_escape($v);
	}

	my $txnString = $self->_format_transactions(@{$p->{transactions}});

	$content .= "&" . $txnString;

	my $url = $self->{url} . "/transactions.xml";

	my $request = HTTP::Request::Common::POST($url, Content=>$content);

	$self->_debug( "start> sending request: ", $request->as_string );
	my $response = $self->{ua}->request($request);

	$self->_debug( "start> got response : ", $response->as_string );

	if ( not $response->is_success ) {
		return $self->_wrap_error($response);
	}

	$self->_debug( "success" );

	return Net::ThreeScale::Response->new(
		error_code  => TS_RC_SUCCESS,
		success     => 1,
	);
}

#Wraps an HTTP::Response message into a Net::ThreeScale::Response error return value
sub _wrap_error {
	my $self = shift;
	my $res  = shift;
	my $error_code;
	my $message;

	eval { ( $error_code, $message ) = $self->_parse_errors( $res->content() ); };

	if ($@) {
		$error_code = TS_RC_UNKNOWN_ERROR;
		$message    = 'unknown_error';
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
					if ( defined( $atts{code} ) ) {
						$errcode = $atts{code};
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

sub _parse_authorize_response {
	my $self          = shift;
	my $response_body = shift;

	my $xml = new XML::Simple(ForceArray=>['usage_report']);

	my $data = {};

	if (length($response_body)) {
		$data = $xml->XMLin($response_body);
	}

	return $data;
}

sub _format_transactions {
	my $self          = shift;
	my (@transactions)  = @_;

	my $output = "";

	my $transNumber = 0;

	for my $trans (@transactions) {
		die("Transactions should be given as hashes")
			unless(ref($trans) eq "HASH");

		die("Transactions need an 'app_id'")
			unless(defined($trans->{app_id}));

		die("Transactions need a 'usage' hash")
			unless(defined($trans->{usage}) and (ref($trans->{usage}) eq "HASH"));

		die("Transactions need a 'timestamp'")
			unless(defined($trans->{app_id}));

		my $pref = "transactions[$transNumber]";

		if ($transNumber > 0) {
				$output .= "&";
		}

		$output .= $pref . "[app_id]=" . $trans->{app_id};

		while (my ($k, $v) = each(%{$trans->{usage}})) {
			$k = uri_escape($k);
			$v = uri_escape($v);
			$output .= "&";
			$output .= $pref . "[usage][$k]=$v";
		}

		$output .= "&" . $pref . "[timestamp]=" . uri_escape($trans->{timestamp});

		$transNumber += 1;
	}

	return $output;
}

sub _debug {
	my $self = shift;
	if ( $self->{DEBUG} ) {
		print STDERR "DBG:", @_, "\n";
	}

}
1;

=head1 NAME

Net::ThreeScale::Client - Client for 3Scale.com web API version 2.0

=head1 SYNOPSIS

 use Net::ThreeScale::Client;
 
 my $client = new Net::ThreeScale::Client(provider_key=>"my_assigned_provider_key", 
                                        url=>"http://su1.3Scale.net");
 
 my $response = $client->authorize(app_id  => $app_id,
                                   app_key => $app_key);
          
 if($response->is_success) {
       print "authorized ", $response->transaction,"\"n";
   ...

   my @transactions = (
      {
         app_id => $app_id,
         usage => {
           hits => 1,
         },

         timestamp => "2010-09-01 09:01:00",
      },

      {
         app_id => $app_id,
         usage => {
            hits => 1,
         },

         timestamp => "2010-09-02 09:02:00",
      }
   );

   my $report_response = $client->report(transactions=>\@transactions));
   if($report_response->is_success){
      print STDERR "Transactions reported\n";
   } else {
      print STDERR "Failed to report transactions",
                  $response->error_code(),":",
                  $response->error_message(),"\n";
   }
 } else {
   print STDERR "authorize failed with error :", 
      $response->error_message,"\n";
   if($response->error_code == TS_RC_AUTHORIZE_FAILED) {
      print "Provider key is invalid";
   } else { 
     ...
   }
 }

=head1 CONSTRUCTOR
 
 The class method new(...) creates a new 3Scale client object. This may 
 be used to conduct transactions with the 3Scale service. The object is 
 stateless and transactions may span multiple clients. The following 
 parameters are recognised as arguments to new():

=over 4
 
=item provider_key 

(required) The provider key used to identify you with the 3Scale service

=item url 

(optional) The 3Scale service URL, usually this should be left to the 
default value 

=back

=head1 $response = $client->authorize(app_id=>$app_id, app_key=>$app_key)

Starts a new client transaction the call must include a application id (as 
a string) and (optionally) an application key (string), identifying the
application to use.
 
Returns a Net::ThreeScale::Response object which indicates whether the 
authorization was successful or indicates an error if one occured.  
 
=head1 $response = $client->report(transactions=>\@transactions)

Reports a list of transactions to 3Scale.

=over 4

=item transactions=>{app_id=>value,...}

Should be an array similar to the following:

=over 4

  my @transactions = (
    { 
      app_id => $app_id,
      usage => {
        hits => 1,
     }
     timestamp => "2010-09-01 09:01:00",
    },
    { 
      app_id => $app_id,
      usage => {
        hits => 1,
      }
      timestamp => "2010-09-01 09:02:00",
    },
  );

=back

=back

=head1 EXPORTS / ERROR CODES

The following constants are exported and correspond to error codes 
which may appear in calls to Net::ThreeScale::Response::error_code

=over 4

=item TS_RC_SUCCESS

The operation completed successfully 


=item TS_RC_AUTHORIZE_FAILED

The  passed provider key was invalid

=item TS_RC_UNKNOWN_ERROR

An unspecified error occurred.  See the corresponding message for more detail.

=back

=head1 SEE ALSO 

=over 4

=item  Net::ThreeScale::Response

Contains details of response contnet and values. 
 
=back

=head1 AUTHOR 

(c) Owen Cliffe 2008, Eugene Oden 2010
