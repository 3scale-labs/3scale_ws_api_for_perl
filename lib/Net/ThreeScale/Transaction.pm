package Net::ThreeScale::Transaction;
use Data::Dumper;
sub new {
	my $class = shift;
	my $params = ( $#_ == 0 ) ? { %{ (shift) } } : {@_};	
	return bless $params, $class;
}
use overload ( '""' => 'stringify' );

sub stringify
{
	my ($self) = @_;
	return $self->id ;
}

sub id {
	return $_[0]->{id};
}

sub contract_name {
	return $_[0]->{contract_name};
}

sub provider_verification_key {
	return $_[0]->{provider_verification_key};
}
1;
=head1 NAME

Net::ThreeScale::Transaction - object encapsulating transaction information in a 3Scale response

=head1 SYNOPSIS
 
 $response = $client->start($user_key);
 if($response->is_success){ 
	my $transaction = $response->transaction;
    print "got transaction ",$transaction,"\n";
    print "TID: " ,$transaction->id,"\n",
          "contract name: ",$transaction->contract_name,"\n", 
          "provider verification key:",$transaction->provider_verfication_key,"\n";
 }

=head1 DESCRIPTION
	
The transaction object is returnd within a Net::ThreeScale::Response object by the 
Net::ThreeScale::Client->start  method. It includes the following read only fields: 

=over 4

=item $transaction->id

The transaction identifier

=item $transaction->contract_name

A string identifying the contract related to the transaction 

=item $transaction->provider_verification_key

The provider verification key 

=back

=head1 SEE ALSO

Net::ThreeScale::Client Net::ThreeScale::Response