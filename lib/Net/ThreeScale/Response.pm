package Net::ThreeScale::Response;

sub new {
	my $class = shift; 
	my $self = {@_};
	return bless $self, $class;	
}

sub is_success{
	return $_[0]->{success};	
}


sub transaction{
	return $_[0]->{transaction};
}

sub error_code{
	return $_[0]->{error_code};	
}

sub error_message{
	return $_[0]->{error_message};
}

sub errors{
	return $_[0]->{errors};
}  
1;
=head1 NAME

Net::ThreeScale::Response - object encapsulating a response to a 3Scale API call

=head1 SYNOPSIS

 $response = $client->start($user_key);
 if($response->is_success){ 
	my $transaction = $response->transaction;
 }else{ 
 	print STDERR "An error occurred with code ", $response->error_code, ":" ,$response->error,"\n";
 }
 
=head1 DESCRIPTION

A response object is returned from various calls in the 3Scale API, the following fields are of relevance:
Objects are constructed within the API, you should not create them yourself.

=over 4

=item $r->is_success

Indicates if the operation which generated the response was successfull. Successful responses will 
have an associated transaction within the response. 
 
=item $r->transaction

A Net::ThreeScale::Transaction object which encapsualates some information about the transaction, 
this object will always have at least a transaction ID set (id).
 
=item $r->error_code

Returns the error code  (as a string) which was genrerated by this response, these correspond 
to constants exported by the Net::ThreeScale::Client module. see 
Net::ThreeScale::Client for a list of available response codes. 

 
=item $r->error_message

Returns a textual description of the error returned by the server. 

=back

=head1 SEE ALSO

Net::ThreeScale::Client ThreeScale::Transaction 
 
=head1 AUTHOR
  Owen Cliffe 
