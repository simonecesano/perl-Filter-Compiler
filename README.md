# perl-Filter-Compiler

A module for compiling data structures into filter subroutine
references à la SQL::Abstract


# SYNOPSIS

    use Filter::Compiler qw/filter to_code/;

    my $criteria = { tre => [ -and => { '!=', 3 }, { '!=', 4 } ] };

    my @array = (); # array of hashes

    my $sub = filter($criteria);

    my @filtered = grep { $sub->($_) } @array;

# FUNCTIONS

## to\_code

    my $criteria = { tre => [ -and => { '!=', 3 }, { '!=', 4 } ] };

    my $sub = to_code($criteria);
    
    print $sub;

    # sub { ($_[0]->{tre} != 3 and $_[0]->{tre} != 4)}

Converts a structure (arrayref or hash) to code that can be used to create a filter function;

## filter

    my $criteria = { tre => [ -and => { '!=', 3 }, { '!=', 4 } ] };

    my $sub = filter($criteria);

    print $sub->({ tre => 5 })

    # 1

Converts a structure to a sub that can be used as filter

# Filter structures

This module tries to behave as closely as possible to SQL::Abstract,
but it may not be 100% compatible everywhere. The main logic of this
module is that things in arrays are OR'ed, and things in hashes are
AND'ed.

### Simple equality

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

### Lists of values

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

### Equality operators

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

### string and number values

String values are handled so that 

    { tre => { '>=' => [ '3', '4' ] } }

will result in

    sub {
        $_[0]{'tre'} ge 4 or $_[0]{'tre'} ge 3;
    }

# LICENSE

This is released under the Artistic 
License. See [perlartistic](https://metacpan.org/pod/perlartistic).

# AUTHOR

Simone Cesano

