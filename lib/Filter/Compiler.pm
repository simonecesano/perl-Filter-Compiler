use strict;
no warnings;
package Filter::Compiler;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(filter to_code);

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

sub to_code {
    my $q = clone(shift);
    my $h;

    for (ref $q) {
    	/HASH/  && do { $h = convert_hash($q); last };
    	/ARRAY/ && do { $h = convert_array($q); last };
    };

    my $code = _to_code_recursive($h);
    return 'sub { ' . $code . '}' 
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
    return eval 
}

sub filter {
    my $q = clone($_[0]);

    my $code = to_code($q);
    return eval $code 
}


=pod
 
=encoding utf8

=head1 DESCRIPTION
 
A module for compiling data structures into filter subroutine
references à la SQL::Abstract

=head1 SYNOPSIS

    use Filter::Compiler qw/filter to_code/;

    my $criteria = { tre => [ -and => { '!=', 3 }, { '!=', 4 } ] };

    my @array = (); # array of hashes

    my $sub = filter($criteria);

    my @filtered = grep { $sub->($_) } @array;

=head1 FUNCTIONS

=head2 to_code

    my $criteria = { tre => [ -and => { '!=', 3 }, { '!=', 4 } ] };

    my $sub = to_code($criteria);
    
    print $sub;

    # sub { ($_[0]->{tre} != 3 and $_[0]->{tre} != 4)}

Converts a structure (arrayref or hash) to code that can be used to create a filter function;

=head2 filter

    my $criteria = { tre => [ -and => { '!=', 3 }, { '!=', 4 } ] };

    my $sub = filter($criteria);

    print $sub->({ tre => 5 })

    # 1

Converts a structure to a sub that can be used as filter

=head1 Filter structures

This module tries to behave as closely as possible to SQL::Abstract,
but it may not be 100% compatible everywhere. The main logic of this
module is that things in arrays are OR'ed, and things in hashes are
AND'ed.

=head3 Simple equality

A hash like this

    { tre => 3 }

will result in

    sub {
        $_[0]{'tre'} == 3;
    }


and empty values are handled too so this

    { tre => '' }

will result in

    sub {
        $_[0]{'tre'} eq '';
    }

=head3 Lists of values

Lists of values are or'ed so this

    { tre => [ 3, 4 ] }

will result in

    sub {
        $_[0]{'tre'} == 4 unless $_[0]{'tre'} == 3;
    }

and an array of hashes

    [ { uno => 1 }, { due => 2 } ]

will result in

    sub {
        $_[0]{'due'} == 2 unless $_[0]{'uno'} == 1;
    }

    { tre => [ -and => { '!=', 3 }, { '!=', 4 } ] }

will result in

    sub {
        $_[0]{'tre'} != 4 && $_[0]{'tre'} != 3;
    }

=head3 Equality operators

Equality operators are handled if put at the beginning of the hash
used as the filter value  

    { tre => { '<' => [ 3, 4 ] } }

will result in

    sub {
        $_[0]{'tre'} < 4 or $_[0]{'tre'} < 3;
    }

and regexes are handled too so

    { tre => { '=~' => [ qr/3/i, qr/4/ ] } }

will result in

    sub {
        $_[0]{'tre'} =~ /(?^:4)/ or $_[0]{'tre'} =~ /(?^i:3)/;
    }

=head3 string and number values

String values are handled so that 

    { tre => { '>=' => [ '3', '4' ] } }

will result in

    sub {
        $_[0]{'tre'} ge 4 or $_[0]{'tre'} ge 3;
    }

=head1 LICENSE

This is released under the Artistic 
License. See L<perlartistic>.

=head1 AUTHOR

simone

=cut

1;
