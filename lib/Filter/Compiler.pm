use strict;
no warnings;
package Filter::Compiler;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(filter to_code convert_array convert_hash);

use Text::Quote;
use Clone 'clone';

my $q = Text::Quote->new;

sub is_number { return length do { no warnings "numeric"; (shift) & '' } };

sub convert_array {
    my $v = clone(shift);

    my $boo = shift || '||';
    
    if (($v->[0] eq '-and') || ($v->[0] eq '-or')) {
	$boo = lc((shift @$v) =~ s/^\-//r);
    }

    return { $boo => [ map {
	ref $_ eq 'HASH' ? 
	    convert_hash($_) :
	    convert_array($_, $boo)
    } @$v ] };
}

sub convert_hash {
    my $h = clone(shift);
    my $eq = shift || '==';
    my $boo = shift || '&&';

    my @ret = ();
    
    for my $k (keys %$h) {
	my $v = $h->{$k};
	my $ref = ref $v;
	
	
	for ($ref) {
	    /ARRAY/ && do {
		if (($v->[0] eq '-and') || ($v->[0] eq '-or')) {
		    $boo = lc((shift @$v) =~ s/^\-//r);
		} else {
		    $boo = '||';
		}
		
		for (@$v) { push @ret, convert_hash({ $k => $_ }, $eq) }
		last;
	    };
	    /HASH/ && do {
		my ($eq) = keys %$v;
		

		
		if ($eq eq '!=') { $boo = '&&' }
		
		push @ret, convert_hash({ $k => $v->{$eq} }, $eq, $boo);
		last;
	    };
	    push @ret, [$k, $eq, $v];
	}
    }
    return @ret > 1 ? { $boo => \@ret } : $ret[0];
}
use Mojo::JSON qw/encode_json/;

sub to_code {
    my $q = clone(shift);
    my $h;

    for (ref $q) {
    	/HASH/  && do { $h = convert_hash($q); last };
    	/ARRAY/ && do { $h = convert_array($q); last };
    };

    print 'converted: ' . encode_json($h);
    _to_code_recursive($h);
}

sub _to_code_recursive {
    my $h = clone($_[0]);
    
    my $str_eq = { '==' => 'eq', '!=' => 'ne', '>' => 'gt', '<', => 'lt', '>=' => 'ge', '<=' => 'le' };
    for (ref $h) {
	/HASH/ && do {
	    my ($boo) = (keys %$h);
	    my @val = map { _to_code_recursive($_) } @{$h->{$boo}};
	    return sprintf '(%s)', (join (" $boo ", @val));
	};
	/ARRAY/ && do {
	    unless (is_number($h->[2])) {
		$h->[1] = $str_eq->{$h->[1]} || $h->[1];
		$h->[2] = $q->quote($h->[2]);
	    }
	    return sprintf '$_[0]->{%s} %s %s', @$h;
	};
    }
}

sub filter_b {
    my $q = clone($_[0]);
    my $h;

    for (ref $q) {
    	/HASH/ && do { $h = convert_hash($q); last };
    	/ARRAY/ && do { $h = convert_array($q); last };
    }

    my $code = _to_code_recursive($h);
    return eval 'sub { ' . $code . '}' 
}

sub filter {
    my $q = clone($_[0]);

    my $code = to_code($q);
    return eval 'sub { ' . $code . '}' 
}


=pod

1. hash with scalar
2. hash with array
3. hash with equality function
4. hash with equality and array

return them all as field equality value

=cut


1;
