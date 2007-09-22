package Data::Rand;

use warnings;
use strict;
use List::Util  ();

use version; our $VERSION = qv('0.0.1');

use base 'Exporter';
our @EXPORT    = qw( rand_data );
our @EXPORT_OK = qw( rand_data_string rand_data_array );

sub rand_data {
	my $options_hr = ref $_[-1] eq 'HASH' ? pop @_ : {}; # last item a hashref or not
	%{ $options_hr->{'details'} }= ();
	
    my ( $size, $items_ar ) = @_;

    my $seeder = ref $options_hr->{'srand_seeder_coderef'} eq 'CODE' 
        ? $options_hr->{'srand_seeder_coderef'} : sub { return int( rand( 999_999_999_999_999 ) ); };

    $size = 32 if !defined $size || $size eq '0' || $size !~ m{ \A \d+ \z }xms;
    $options_hr->{'details'}{'size'} = $size;

    my $entropy = int( $seeder->() ) || int( rand( 999_999_999_999_999 ) );
    $options_hr->{'details'}{'entropy'} = $entropy;

    my $time = time;
    $options_hr->{'details'}{'time'} = $time;

    if ( $options_hr->{'use_time_hires'} ) {
	    require Time::HiRes if !exists $INC{'Time/HiRes.pm'};
	    my ($sec, $mic) = Time::HiRes::gettimeofday();
	    $options_hr->{'details'}{'hires'} = [$sec, $mic];
	    $time = $sec ^ $mic;
    }

    srand( $time ^ $$ ^ $entropy );

    my @items = ( 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );
    my $def_list = 1;

    if ( ref $items_ar eq 'ARRAY' ) {
        if ( @{ $items_ar } ) {
	        @items = @{ $items_ar };
	        $def_list = 0;
        }	
    }
    $options_hr->{'details'}{'using_default_list'} = $def_list;
    $options_hr->{'details'}{'items'} = [ @items ];

    my @chars = List::Util::shuffle( @items );

    if ( $options_hr->{'use_unique_list'} && !$def_list ) {
        my %uniq;
	    @chars = map { $uniq{$_}++ == 0 ? $_ : () } @_; # see List::MoreUtils::uniq() #left prec, reverse @_ right prec
    }

    $size = @chars if $size > @chars && $options_hr->{'do_not_repeat_index'};

    my @data;
    my %used;
    
    for ( 1 .. $size ) {
	    my $index = int rand scalar @chars;
        if( $options_hr->{'do_not_repeat_index'} ) {
		    while ( exists $used{ $index } ) {
			    $index = int rand scalar @chars;
		    }
		    $used{ $index }++;
        }

        push @data, $chars[ $index ];
    }

    return wantarray ? @data : join('', @data);
}

sub rand_data_string {
    return scalar( rand_data(@_) );	
}

sub rand_data_array {
	my @rand = rand_data(@_);
	return wantarray ? @rand : \@rand;
}

1; 

__END__

=head1 NAME

Data::Rand - Efficient cryptographically strong random strings and lists of [un]given length and data.

=head1 VERSION

This document describes Data::Rand version 0.0.1

=head1 SYNOPSIS

    use Data::Rand;

	my $rand_32_str = rand_data();

    my $rand_64_str = rand_data(64);

	my @contestants = rand_data( 2, \@studio_audience, { 'do_not_repeat_index' => 1 } ); 

	my $doubledigit = rand_data( 2, [0 .. 9] );
	
	my @rolled_dice = rand_data( 2, [1 .. 6] );

    my $pickanumber = rand_data( 1, [1 .. 1000] );

=head1 DESCRIPTION

Simple interface to efficiently get cryptographically strong randomized data.

=head1 EXPORT

rand_data() is exported by default. rand_data_string() and rand_data_array() are exportable.

=head1 INTERFACE 

=head2 rand_data()

In scalar context returns a string made of a number of parts you want made up from an array of parts.

In array context it returns a list the length of number of parts you want where each item is from the array of parts.

Takes 0 to 3 arguments:

=over

=item 1) length or number of random parts (default if not given or invalid is 32)

=item 2) array ref of parts (default if not given or invalid is 0 .. 9 and upper and lower case a-z)

=item 3) hashref of behavioral options

keys and values are described below, unless otherwise noted options are booleans which default to false

=over

=item * 'use_time_hires'

Have srand calculation use high resolution time data instead of normal time(). Makes for even stronger randomness for crytographical purposes. 

=item * 'use_unique_list' 

Make sure array of parts is unique. If you're passing the same list more than once and you are doing this each time it'd be more efficient to uniq() the list once and pass that to the function instead of using this.

=item * 'do_not_repeat_index' 

Do not use any index of the array of parts more than once.

Caveat: if the length is longer than the list of items then the length is silently adjusted to the length of the list.

    my $length = 10;
    my @random = rand_data( $length, @deck_of_cards, { 'do_not_repeat_index' => 1 } );
    # @random has 10 items

    my $length = 53;
    my @random = rand_data( $length, @deck_of_cards, { 'do_not_repeat_index' => 1 } );
    # @random has 52 items

Caveat: This is not a uniq() functionality on the list of items, this is "no repeat" based on index. So:

    rand_data(3, [qw(dan dan dan)]);

is valid (if not very useful) because it won't use index 0, 1, or 2 more than once

This is probably what you'd want:

    rand_data($n, [ uniq @people ] ); # could still contain duplicates in results by using the same index more than once

or even:

    rand_data($n, \@people, { 'do_not_repeat_index' => 1, 'use_unique_list' => 1 } ); # definitely no duplicates since you uniq()ed the list *and* told it to only use each index at most once

Caveat: This also increases calculation time since it has to see if 
a randomly chosen index has already been used and if so try again. 

=item * 'srand_seeder_coderef'

See "SEEDING RANDOM GENERATOR"

This sets the internal function used to generate part of the srand calculation.

It's value must be a coderef or its ignored. It must return an int() or its return value is ignored.

A few examples in line with srand perldoc:

    sub { return unpack '%L*', `ps axww | gzip` } 

    \&Math::TrulyRandom::truly_random_value

=back

=back

=head2 rand_data_string()

Same args as rand_data(). The difference is that it always returns a string regardless of context.

    my $rand_str = rand_data_string( @rand_args ); # $rand_str contains the random string.
    my @stuff    = rand_data_string( @rand_args ); # $stuff[0] contains the random string.

=head2 rand_data_array()

Same args as rand_data(). The difference is that it always returns an array regardless of context.

    my @rand_data = rand_data_array( @rand_args ); # @rand_data contains the random items
    my $rand_data = rand_data_array( @rand_args ); # $rand_data is an array ref to the list of random items

=head1 SEEDING RANDOM GENERATOR

Internally it uses srand as per the docs and a part of the seed calculation can be changed to your needs.

If a random int between 0 and 999,999,999,999,999 is not what you want for that part of the calulation, feel free to change it via the hashref argument described above.

Note: this is only *one* component in the srand arg calculation *NOT* the entire srand() arg, so don't panic :)

=head1 DIAGNOSTICS

Throws no warnings or errors of its own.

=head1 CONFIGURATION AND ENVIRONMENT
  
Data::Rand requires no configuration files or environment variables.

=head1 DEPENDENCIES

L<List::Util> to shuffle the array of items to use for the randomized data.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-data-rand@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 TODO

May add these behaviorial booleans to option hashref depending on feedback:

    'return_on_bad_args' # do not use defaults, just return;
    'carp_on_bad_args'   # carp() about what args are bad and why
    'croak_on_bad_args'  # same as carp but fatal

=head1 AUTHOR

Daniel Muey  C<< <http://drmuey.com/cpan_contact.pl> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Daniel Muey C<< <http://drmuey.com/cpan_contact.pl> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.