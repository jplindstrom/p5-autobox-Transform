package autobox::Transform;

use strict;
use warnings;
use parent qw/autobox/;

our $VERSION = "1.000";

=head1 NAME

autobox::Transform - Autobox methods to transform Arrays and Hashes

=head1 SYNOPSIS

    # These are equivalent ways to transform arrays and arrayrefs

    ### map_by
    my @genres = map { $_->genre() } @$books;
    my @genres = $books->map_by("genre");

    my $genres = [ map { $_->genre() } @$books ];
    my $genres = $books->map_by("genre");

    # With sum from autobox::Core / List::AllUtils
    my $book_order_total = sum(
        map { $_->price_with_tax($tax_pct) } @{$order->books}
    );
    my $book_order_total = $order->books
        ->map_by(price_with_tax => [$tax_pct])->sum;


    ### grep_by
    my $sold_out_books = [ grep { $_->is_sold_out } @$books ];
    my $sold_out_books = $books->grep_by("is_sold_out");

    my $books_in_library = [ grep { $_->is_in_library($library) } @$books ];
    my $books_in_library = $books->grep_by(is_in_library => [$library]);


    ### group_by

    $books->group_by("title"),
    # {
    #     "Leviathan Wakes"       => $books->[0],
    #     "Caliban's War"         => $books->[1],
    #     "The Tree-Body Problem" => $books->[2],
    #     "The Name of the Wind"  => $books->[3],
    # },

    $authors->group_by(publisher_affiliation => ["with"]),
    # {
    #     'James A. Corey with Orbit'     => $authors->[0],
    #     'Cixin Liu with Head of Zeus'   => $authors->[1],
    #     'Patrick Rothfuss with Gollanz' => $authors->[2],
    # },

    $books->group_by_count("genre"),
    # {
    #     "Sci-fi"  => 3,
    #     "Fantasy" => 1,
    # },

    my $genre_books = $books->group_by_array("genre");
    # {
    #     "Sci-fi"  => [ $sf_book_1, $sf_book_2, $sf_book_3 ],
    #     "Fantasy" => [ $fantasy_book_1 ],
    # },


    #### flat
    my $prolific_author_books = [ map { @{$_->books} } @$authors ]
    my $prolific_author_books = $authors->map_by("books")->flat



=head1 DESCRIPTION

Note: This module supercedes autobox::Array::Transform which was
unfortunately named.

High level autobox methods you can call on arrays, arrayrefs, hashes
and hashrefs e.g. map_by(), grep_by(), group_by()


=head2 Raison d'etre

L<autobox::Core> is awesome, for a variety of reasons.

=over 4

=item

It cuts down on dereferencing punctuation clutter.

=item

It makes map and grep transforms read in the same direction it's executed.

=item

It makes it easier to write those things in a natural order. No need
to move the cursor around a lot just to fix dereferencing, order of
operations etc.

=back

autobox::Transform provides a few higher level methods for mapping,
greping and sorting common cases which are easier to read and write.

Since they are at a slightly higher semantic level, once you know them
they also provide a more specific meaning than just "map" or "grep".

(Compare the difference between seeing a "map" and seeing a "foreach"
loop. Just seeing the word "map" hints at what type of thing is going
on here: transforming a list into another list).

The methods of autobox::Transform are not suitable for all
cases, but when used appropriately they will lead to much more clear,
succinct and direct code, especially in conjunction with
autobox::Core.


=head2 Examples

    my $total_order_amount = $order->books
        ->map_by(price_with_tax => [ $tax_pct ])
        ->sum;

    my $order_authors = $order->books
        ->map_by("author")
        ->map_by("name")->uniq->sort->join(", ");

=cut

use true;
use Carp;

sub import {
    shift->SUPER::import( ARRAY => "autobox::Transform::Array" );
}

sub throw {
    my ($error) = @_;
    ###JPL: remove lib
    $error =~ s/ at [\\\/\w ]*?\bautobox.Transform\.pm line \d+\.\n?$//;
    local $Carp::CarpLevel = 1;
    croak($error);
}



package # hide from PAUSE
    autobox::Transform::Array;



=head2 List and Scalar Context

All of the methods below are context sensitive, i.e. they return a
list in list context and an arrayref in scalar context, just like
autobox::Core.

When in doubt, assume they work like C<map> and C<grep>, and convert the
return value to references where you might have an unobvious list
context. E.g.

    $self->my_method(
        # Wrong, this is list context and wouldn't return an arrayref
        books => $books->grep_by("is_published"),
    ),

    $self->my_method(
        # Correct, convert the list to an arrayref
        books => [ $books->grep_by("is_published") ],
    ),
    $self->my_method(
        # Correct, ensure scalar context i.e. an array ref
        books => scalar $books->grep_by("is_published"),
    ),



=head1 AUTOBOX ARRAY METHODS

=cut

sub __invoke_by {
    my $invoke = shift;
    my $array = shift;
    my( $method, $args ) = @_;
    @_ > 0 or Carp::croak("->${invoke}_by() missing argument: \$method");
    $args //= [];
    ref($args) eq "ARRAY"
        or Carp::croak("${invoke}_by('$method', \$args): \$args ($args) is not an array ref");

    my $invoke_sub = {
        map  => sub { [ CORE::map  { $_->$method( @$args ) } @$array ] },
        grep => sub { [ CORE::grep { $_->$method( @$args ) } @$array ] },
    }->{$invoke};

    my $result = eval { $invoke_sub->() }
        or autobox::Transform::throw($@);

    return wantarray ? @$result : $result;
}

=head2 map_by($method, @$args?) : @array | @$array

Call the $method on each item in the list. Like:

    map { $_->$method() }

Examples:

    my @ahthor_names = $authors->map_by("name");
    my $author_names = @publishers->map_by("authors")->map_by("name");

Optionally pass in @$args in the method call. Like:

    map { $_->$method(@$args) }

Examples:

    my @prices_including_tax = $books->map_by("price_with_tax", [ $tax_pct ]);
    my $prices_including_tax = $books->map_by(price_with_tax => [ $tax_pct ]);

=cut

sub map_by {
    return __invoke_by("map", @_);
}



=head2 grep_by($method, @$args?) : @array | @$array

Call the $method on each item in the list. Like:

    grep { $_->$method() }

Examples:

    my @prolific_authors = $authors->grep_by("is_prolific");

Optionally pass in @$args in the method call. Like:

    grep { $_->$method(@$args) }

Examples:

    my @books_to_charge_for = $books->grep_by("price_with_tax", [ $tax_pct ]);

=cut

sub grep_by {
    return __invoke_by("grep", @_);
}

# grep_by $value, if passed the method value must match the value




=head2 group_by($method, @$args = [], $value_sub = count) : %key_value | %$key_value

Call ->$method(@$args) on each object in the array (just like ->map_by)
and group the return values as keys in a hashref.

The default $value_sub gives the count of each value as the values of
the hashref.

Example:

    my $genre_count = $books->group_by("genre");
    # {
    #     "Sci-fi"  => 3,
    #     "Fantasy" => 1,
    # },

=head3 The $value_sub

This is a bit tricky to use, so the most common thing would probably
be to use canned utility subs which do common things (see below).

The hash key is whatever is returned from $object->$method(@$args).

The hash value is whatever is returned from

    my $new_value = $value_sub->($current_value, $object, $key);

where:

=over 4

=item

$current value is the current hash value for this key (or undef if the first one).

=item

$object is the current item in the list. The current $_ is also set to this.

=item

$key is the key returned by $object->$method(@$args)

=back

=cut

sub group_by {
    my $array = shift;
    my( $method, $args, $value_sub ) = @_;
    @_ > 0 or Carp::croak("->group_by() missing argument: \$method");

    $args //= [];
    ref($args) eq "ARRAY"
        or Carp::croak("group_by('$method', \$args, \$value_sub): \$args ($args) is not an array ref");

    $value_sub //= sub { $_ };
    ref($value_sub) eq "CODE"
        or Carp::croak("group_by('$method', [], \$value_sub): \$value_sub ($value_sub) is not a sub ref");

    my %key_value;
    for my $object (@$array) {
        my $key_ref = eval { [ $object->$method(@$args) ] }
            or autobox::Transform::throw($@);
        my $key = $key_ref->[0];

        my $current_value = $key_value{ $key };
        local $_ = $object;
        my $new_value = $value_sub->($current_value, $object, $key);

        $key_value{ $key } = $new_value;
    }

    return wantarray ? %key_value : \%key_value;
}

sub group_by_count {
    my $array = shift;
    my( $method, $args ) = @_;
    ###JPL: extract args checking
    @_ > 0 or Carp::croak("->group_by_count() missing argument: \$method");

    $args //= [];
    ref($args) eq "ARRAY"
        or Carp::croak("group_by_count('$method', \$args): \$args ($args) is not an array ref");

    my $value_sub = sub {
        my $count = shift // 0; return ++$count;
    };

    return group_by($array, $method, $args, $value_sub);
}

sub group_by_array {
    my $array = shift;
    my( $method, $args ) = @_;
    ###JPL: extract args checking
    @_ > 0 or Carp::croak("->group_by_array() missing argument: \$method");

    $args //= [];
    ref($args) eq "ARRAY"
        or Carp::croak("group_by_array('$method', \$args): \$args ($args) is not an array ref");

    my $value_sub = sub {
        my $array = shift // [];
        push( @$array, $_ );
        return $array;
    };

    return group_by($array, $method, $args, $value_sub);
}


=head2 flat() : @array | @$array

Return a flattened array, assuming the array items themselves are
array refs. I.e.

    [
        [ 1, 2, 3 ],
        [ "a", "b" ],
    ]->flat

returns

    [ 1, 2, 3, "a", "b "]

This is useful if e.g. a map_by("some_method") returns arrayrefs of
objects which you want to do further method calls on. Example:

    # ->books returns an arrayref of Book objects with a ->title
    $authors->map_by("books")->flat->map_by("title")

Note: This is different from autobox::Core's ->flatten, which reurns a
list rather than an array and therefore can't be used in this
way.

=cut

sub flat {
    my $array = shift;
    ###JPL: eval and report error from correct place
    my $result = [ map { @$_ } @$array ];
    return wantarray ? @$result : $result;
}



# TODO:
# find(sub), like grep
# find_by($method, $args, $value), like grep_by but first
# contains value
# compact - without undefined
# compactTrue - without false
# without - grep -v value


# Hash::Transform: map_by() maps values from one thing to another




=head1 DEVELOPMENT

=head2 Author

Johan Lindstrom, C<< <johanl [AT] cpan.org> >>


=head2 Source code

L<https://github.com/jplindstrom/p5-autobox-Transform>


=head2 Bug reports

Please report any bugs or feature requests on GitHub:

L<https://github.com/jplindstrom/p5-autobox-Transform/issues>.



=head1 COPYRIGHT & LICENSE

Copyright 2016- Johan Lindstrom, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
