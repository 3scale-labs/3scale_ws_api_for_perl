use 5.006;
use ExtUtils::MakeMaker;


WriteMakefile(
	'NAME'         => 'Net::ThreeScale::Client',
	'VERSION_FROM' => 'lib/Net/ThreeScale/Client.pm',
	'PREREQ_PM'    => {
		'LWP'                 => 0,
		'HTTP::Request'       => 0,
		'YAML'                => 0,
		'XML::Simple'         => 0
	},
	ABSTRACT_FROM => 'lib/Net/ThreeScale/Client.pm',
	AUTHOR        => 'Owen Cliffe <zoot@zoot.org.uk>',
);

sub MY::postamble {
	my $self = shift;
	my $old  = $self->MM::postamble(@_);
	chomp($old);
	my $new = <<'EON';

.PHONY : aux readme

aux : readme

readme : lib/Net/ThreeScale/Client.pm
	perldoc -t lib/Net/ThreeScale/Client.pm > README

EON
	return $old . $new;
}
