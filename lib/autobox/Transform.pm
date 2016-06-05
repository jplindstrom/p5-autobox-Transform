package autobox::Transform;

use strict;
use warnings;
use parent qw/autobox/;

our $VERSION = "1.008";

=head1 NAME

autobox::Transform - Autobox methods to transform Arrays and Hashes

=head1 SYNOPSIS

=head2 Examples

    use autobox::Core;  # uniq, sort, join, sum, etc.
    use autobox::Transform;

    $books->map_by("genre");
    $books->map_by(price_with_tax => [$tax_pct]);

    $books->grep_by("is_sold_out");
    $books->grep_by(is_in_library => [$library]);

    $books->uniq_by("id");

    $books->group_by("title");
    $books->group_by_count("genre")
    $books->group_by_array("genre")

    $authors->map_by("books")->flat;

    my $order_authors = $order->books
        ->uniq_by("isbn")
        ->map_by("author")
        ->map_by("name")->uniq->sort->join(", ");

    my $total_order_amount = $order->books
        ->grep_by(not_covered_by_vouchers => [ $vouchers ])
        ->map_by(price_with_tax => [ $tax_pct ])
        ->sum;


=head2 Comparison of vanilla Perl and autobox version

    ### map_by - method call: $books are Book objects
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

    ### map_by - hash key: $books are book hashrefs
    my @genres = map { $_->{genre} } @$books;
    my @genres = $books->map_by("genre");



    ### grep_by - method call: $books are Book objects
    my $sold_out_books = [ grep { $_->is_sold_out } @$books ];
    my $sold_out_books = $books->grep_by("is_sold_out");

    my $books_in_library = [ grep { $_->is_in_library($library) } @$books ];
    my $books_in_library = $books->grep_by(is_in_library => [$library]);

    ### grep_by - hash key: $books are book hashrefs
    my $sold_out_books = [ grep { $_->{is_sold_out} } @$books ];
    my $sold_out_books = $books->grep_by("is_sold_out");



    ### uniq_by - method call: $books are Book objects
    my %seen; my $distinct_books = [ grep { ! %seen{ $_->id // "" }++ } @$books ];
    my $distinct_books = $books->uniq_by("id");

    ### uniq_by - hash key: $books are book hashrefs
    my %seen; my $distinct_books = [ grep { ! %seen{ $_->{id} // "" }++ } @$books ];
    my $distinct_books = $books->uniq_by("id");



    ### group_by - method call: $books are Book objects

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


    ### group_by - hash key: $books are book hashrefs
    $books->group_by("title"), # $books are hashrefs



    #### flat - $author->books returns an arrayref of Books
    my $author_books = [ map { @{$_->books} } @$authors ]
    my $author_books = $authors->map_by("books")->flat



=head1 DESCRIPTION

High level autobox methods you can call on arrays, arrayrefs, hashes
and hashrefs.

=over 4

=item

$array->map_by()

=item

$array->grep_by()

=item

$array->uniq_by()

=item

$array->group_by()

=item

$array->group_by_count()

=item

$array->group_by_array()

=item

$array->flat()

=back


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


=cut

use true;
use Carp;

sub import {
    my $self = shift;
    $self->SUPER::import( ARRAY => "autobox::Transform::Array" );
    $self->SUPER::import( HASH  => "autobox::Transform::Hash"  );
}

sub throw {
    my ($error) = @_;
    ###JPL: remove lib
    $error =~ s/ at [\\\/\w ]*?\bautobox.Transform\.pm line \d+\.\n?$//;
    local $Carp::CarpLevel = 1;
    croak($error);
}



=head2 Transforming lists of objects vs list of hashrefs

map_by, grep_by etc are called the same way regardless of whether the
list contains objects or hashrefs. The items in the list must all be
either objects or hashrefs.

If the array contains objects, a method is called on each object
(possibly with the arguments provided).

If the array contains hashrefs, the hash key is looked up on each
item.


=head2 List and Scalar Context

All of the methods below are context sensitive, i.e. they return a
list in list context and an arrayref in scalar context, just like
autobox::Core.

Beware: you might be in list context when you need an arrayref.

When in doubt, assume they work like C<map> and C<grep>, and convert
the return value to references where you might have an unobvious list
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

package # hide from PAUSE
    autobox::Transform::Array;



sub __invoke_by {
    my $invoke = shift;
    my $array = shift;
    my( $accessor, $args ) = @_;
    @_ > 0 or Carp::croak("->${invoke}_by() missing argument: \$accessor");
    @$array or return wantarray ? () : [ ];

    if ( ref($array->[0] ) eq "HASH" ) {
        defined($args)
            and Carp::croak("${invoke}_by('$accessor'): \$args ($args) only supported for method calls, not hash key access");
        $invoke .= "_key";
    }

    $args //= [];
    ref($args) eq "ARRAY"
        or Carp::croak("${invoke}_by('$accessor', \$args): \$args ($args) is not an array ref");

    my %seen;
    my $invoke_sub = {
        map      => sub { [ CORE::map  { $_->$accessor( @$args ) } @$array ] },
        map_key  => sub { [ CORE::map  { $_->{$accessor}         } @$array ] },
        grep     => sub { [ CORE::grep { $_->$accessor( @$args ) } @$array ] },
        grep_key => sub { [ CORE::grep { $_->{$accessor}         } @$array ] },
        uniq     => sub { [ CORE::grep { ! $seen{ $_->$accessor( @$args ) // "" }++ } @$array ] },
        uniq_key => sub { [ CORE::grep { ! $seen{ $_->{$accessor}         // "" }++ } @$array ] },
    }->{$invoke};

    my $result = eval { $invoke_sub->() }
        or autobox::Transform::throw($@);

    return wantarray ? @$result : $result;
}

=head2 @array->map_by($accessor, @$args?) : @array | @$array

Call the $accessor on each object in @array, or get the hash key
value on each hashref in the list. Like:

    map { $_->$accessor() }
    # or
    map { $_->{$accessor} }

Examples:

    my @ahthor_names = $authors->map_by("name");
    my $author_names = @publishers->map_by("authors")->map_by("name");

Optionally pass in @$args in the method call. Like:

    map { $_->$accessor(@$args) }

Examples:

    my @prices_including_tax = $books->map_by("price_with_tax", [ $tax_pct ]);
    my $prices_including_tax = $books->map_by(price_with_tax => [ $tax_pct ]);

Or get the hash key value. Examples:

    my @review_scores = $reviews->map_by("score");

=cut

sub map_by {
    return __invoke_by("map", @_);
}



=head2 @array->grep_by($accessor, @$args?) : @array | @$array

Call the $accessor on each object in the list, or get the hash key
value on each hashref in the list. Like:

    grep { $_->$accessor() }
    grep { $_->{$accessor} }

Examples:

    my @prolific_authors = $authors->grep_by("is_prolific");

Optionally pass in @$args in the method call. Like:

    grep { $_->$accessor(@$args) }

Examples:

    my @books_to_charge_for = $books->grep_by("price_with_tax", [ $tax_pct ]);

=cut

sub grep_by {
    return __invoke_by("grep", @_);
}

# grep_by $value, if passed the method value must match the value



=head2 @array->uniq_by($accessor, @$args?) : @array | @$array

Call the $accessor on each object in the list, or get the hash key
value on each hashref in the list. Return list of items wich have a
unique set of return values. The order is preserved. On duplicates,
keep the first occurrence.

Examples:

    # You have gathered multiple Author objects with duplicate ids
    my @authors = $authors->uniq_by("author_id");

Optionally pass in @$args in the method call.

Examples:

    my @example_book_at_price_point = $books->uniq_by("price_with_tax", [ $tax_pct ]);

=cut

sub uniq_by {
    return __invoke_by("uniq", @_);
}



=head2 @array->group_by($accessor, @$args = [], $value_sub = object) : %key_value | %$key_value

Call ->$accessor(@$args) on each object in the array, or get the hash
key for each hashref in the array (just like ->map_by) and group the
return values as keys in a hashref.

The default $value_sub puts each object in the list as the hash
value. If the key is repeated, the value is overwritten with the last
object.

Example:

    my $title_book = $books->group_by("title");
    # {
    #     "Leviathan Wakes"       => $books->[0],
    #     "Caliban's War"         => $books->[1],
    #     "The Tree-Body Problem" => $books->[2],
    #     "The Name of the Wind"  => $books->[3],
    # },

=head3 The $value_sub

This is a bit tricky to use, so the most common thing would probably
be to use one of the more specific group_by-methods (see below). It
should be capable enough to achieve what you need though, so here's
how it works:

The hash key is whatever is returned from $object->$accessor(@$args).

The hash value is whatever is returned from

    my $new_value = $value_sub->($current_value, $object, $key);

where:

=over 4

=item

$current value is the current hash value for this key (or undef if the first one).

=item

$object is the current item in the list. The current $_ is also set to this.

=item

$key is the key returned by $object->$accessor(@$args)

=back

=cut

sub __core_group_by {
    my( $name, $array, $accessor, $args, $value_sub ) = @_;
    $accessor or Carp::croak("->$name() missing argument: \$accessor");
    @$array or return wantarray ? () : { };

    my $invoke = do {
        # Hash key
        if ( ref($array->[0] ) eq "HASH" ) {
            defined($args)
                and Carp::croak("$name('$accessor'): \$args ($args) only supported for method calls, not hash key access. Please specify an undef if needed.");
            "key";
        }
        # Method
        else {
            $args //= [];
            ref($args) eq "ARRAY"
                or Carp::croak("$name('$accessor', \$args, \$value_sub): \$args ($args) is not an array ref");
            "method";
        }
    };

    my $invoke_sub = {
        method => sub { [ shift->$accessor(@$args) ] },
        key    => sub { [ shift->{$accessor}       ] },
    }->{$invoke};

    my %key_value;
    for my $object (@$array) {
        my $key_ref = eval { $invoke_sub->($object) }
            or autobox::Transform::throw($@);
        my $key = $key_ref->[0];

        my $current_value = $key_value{ $key };
        local $_ = $object;
        my $new_value = $value_sub->($current_value, $object, $key);

        $key_value{ $key } = $new_value;
    }

    return wantarray ? %key_value : \%key_value;
}

sub group_by {
    my $array = shift;
    my( $accessor, $args, $value_sub ) = @_;

    $value_sub //= sub { $_ };
    ref($value_sub) eq "CODE"
        or Carp::croak("group_by('$accessor', [], \$value_sub): \$value_sub ($value_sub) is not a sub ref");

    return __core_group_by("group_by", $array, $accessor, $args, $value_sub);
}

=head2 @array->group_by_count($accessor, @$args = []) : %key_count | %$key_count

Just like group_by, but the hash values are the the number of
instances each $accessor value occurs in the list.

Example:

    $books->group_by_count("genre"),
    # {
    #     "Sci-fi"  => 3,
    #     "Fantasy" => 1,
    # },

$book->genre() returns the genre string. There are three books counted
for the "Sci-fi" key.

=cut

sub group_by_count {
    my $array = shift;
    my( $accessor, $args ) = @_;

    my $value_sub = sub {
        my $count = shift // 0; return ++$count;
    };

    return __core_group_by("group_by_count", $array, $accessor, $args, $value_sub);
}

=head2 @array->group_by_array($accessor, @$args = []) : %key_objects | %$key_objects

Just like group_by, but the hash values are arrayrefs containing the
objects which has each $accessor value.

Example:

    my $genre_books = $books->group_by_array("genre");
    # {
    #     "Sci-fi"  => [ $sf_book_1, $sf_book_2, $sf_book_3 ],
    #     "Fantasy" => [ $fantasy_book_1 ],
    # },

$book->genre() returns the genre string. The three Sci-fi book objects
are collected under the Sci-fi key.

=cut

sub group_by_array {
    my $array = shift;
    my( $accessor, $args ) = @_;

    my $value_sub = sub {
        my $array = shift // [];
        push( @$array, $_ );
        return $array;
    };

    return __core_group_by("group_by_array", $array, $accessor, $args, $value_sub);
}


=head2 @array->flat() : @array | @$array

Return a (one level) flattened array, assuming the array items
themselves are array refs. I.e.

    [
        [ 1, 2, 3 ],
        [ "a", "b" ],
        [ [ 1, 2 ], { 3 => 4 } ]
    ]->flat

returns

    [ 1, 2, 3, "a", "b ", [ 1, 2 ], { 3 => 4 } ]

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





=head1 AUTOBOX HASH METHODS

=cut

package # hide from PAUSE
    autobox::Transform::Hash;


sub key_value {
    my $hash = shift;
    my( $original_key, $new_key ) = @_;
    $new_key //= $original_key;
    my %key_value = ( $new_key => $hash->{$original_key} );
    return wantarray ? %key_value : \%key_value;
}

sub __core_key_value_if {
    my $hash = shift;
    my( $comparison_sub, $original_key, $new_key ) = @_;
    $comparison_sub->($hash, $original_key) or return wantarray ? () : {};
    return key_value($hash, $original_key, $new_key)
}

sub key_value_if_exists {
    my $hash = shift;
    my( $original_key, $new_key ) = @_;
    return __core_key_value_if(
        $hash,
        sub { !! exists shift->{ shift() } },
        $original_key,
        $new_key
    );
}

sub key_value_if_true {
    my $hash = shift;
    my( $original_key, $new_key ) = @_;
    return __core_key_value_if(
        $hash,
        sub { !! shift->{ shift() } },
        $original_key,
        $new_key
    );
}

sub key_value_if_defined {
    my $hash = shift;
    my( $original_key, $new_key ) = @_;
    return __core_key_value_if(
        $hash,
        sub { defined( shift->{ shift() } ) },
        $original_key,
        $new_key
    );
}





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
