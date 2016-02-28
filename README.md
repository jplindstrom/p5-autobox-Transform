# NAME

autobox::Transform - Autobox methods to transform Arrays and Hashes

# SYNOPSIS

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

# DESCRIPTION

Note: This module supercedes autobox::Array::Transform which was
unfortunately named.

High level autobox methods you can call on arrays, arrayrefs, hashes
and hashrefs e.g. map\_by(), grep\_by(), group\_by()

## Raison d'etre

[autobox::Core](https://metacpan.org/pod/autobox::Core) is awesome, for a variety of reasons.

- It cuts down on dereferencing punctuation clutter.
- It makes map and grep transforms read in the same direction it's executed.
- It makes it easier to write those things in a natural order. No need
to move the cursor around a lot just to fix dereferencing, order of
operations etc.

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

## Examples

    my $total_order_amount = $order->books
        ->map_by(price_with_tax => [ $tax_pct ])
        ->sum;

    my $order_authors = $order->books
        ->map_by("author")
        ->map_by("name")->uniq->sort->join(", ");

## List and Scalar Context

All of the methods below are context sensitive, i.e. they return a
list in list context and an arrayref in scalar context, just like
autobox::Core.

When in doubt, assume they work like `map` and `grep`, and convert the
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

# AUTOBOX ARRAY METHODS

## map\_by($method, @$args?) : @array | @$array

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

## grep\_by($method, @$args?) : @array | @$array

Call the $method on each item in the list. Like:

    grep { $_->$method() }

Examples:

    my @prolific_authors = $authors->grep_by("is_prolific");

Optionally pass in @$args in the method call. Like:

    grep { $_->$method(@$args) }

Examples:

    my @books_to_charge_for = $books->grep_by("price_with_tax", [ $tax_pct ]);

## group\_by($method, @$args = \[\], $value\_sub = object) : %key\_value | %$key\_value

Call ->$method(@$args) on each object in the array (just like ->map\_by)
and group the return values as keys in a hashref.

The default $value\_sub puts the objects in the list as the hash
values.

Example:

    my $title_book = $books->group_by("title");
    # {
    #     "Leviathan Wakes"       => $books->[0],
    #     "Caliban's War"         => $books->[1],
    #     "The Tree-Body Problem" => $books->[2],
    #     "The Name of the Wind"  => $books->[3],
    # },

### The $value\_sub

This is a bit tricky to use, so the most common thing would probably
be to use one of the more specific group\_by-methods which do common
things (see below). It should be capable enough to achieve what you
need though, so here's how it works:

The hash key is whatever is returned from $object->$method(@$args).

The hash value is whatever is returned from

    my $new_value = $value_sub->($current_value, $object, $key);

where:

- $current value is the current hash value for this key (or undef if the first one).
- $object is the current item in the list. The current $\_ is also set to this.
- $key is the key returned by $object->$method(@$args)

## group\_by\_count($method, @$args = \[\]) : %key\_count | %$key\_count

Just like group\_by, but the hash values are the the number of
instances each $method value occurs in the list.

Example:

    $books->group_by_count("genre"),
    # {
    #     "Sci-fi"  => 3,
    #     "Fantasy" => 1,
    # },

$book->genre() returns the genre string. There are three books counted
for the "Sci-fi" key.

## group\_by\_array($method, @$args = \[\]) : %key\_objects | %$key\_objects

Just like group\_by, but the hash values are arrayrefs containing the
objects which has each $method value.

Example:

    my $genre_books = $books->group_by_array("genre");
    # {
    #     "Sci-fi"  => [ $sf_book_1, $sf_book_2, $sf_book_3 ],
    #     "Fantasy" => [ $fantasy_book_1 ],
    # },

$book->genre() returns the genre string. The three Sci-fi book objects
are collected under the Sci-fi key.

## flat() : @array | @$array

Return a flattened array, assuming the array items themselves are
array refs. I.e.

    [
        [ 1, 2, 3 ],
        [ "a", "b" ],
    ]->flat

returns

    [ 1, 2, 3, "a", "b "]

This is useful if e.g. a map\_by("some\_method") returns arrayrefs of
objects which you want to do further method calls on. Example:

    # ->books returns an arrayref of Book objects with a ->title
    $authors->map_by("books")->flat->map_by("title")

Note: This is different from autobox::Core's ->flatten, which reurns a
list rather than an array and therefore can't be used in this
way.

# DEVELOPMENT

## Author

Johan Lindstrom, `<johanl [AT] cpan.org>`

## Source code

[https://github.com/jplindstrom/p5-autobox-Transform](https://github.com/jplindstrom/p5-autobox-Transform)

## Bug reports

Please report any bugs or feature requests on GitHub:

[https://github.com/jplindstrom/p5-autobox-Transform/issues](https://github.com/jplindstrom/p5-autobox-Transform/issues).

# COPYRIGHT & LICENSE

Copyright 2016- Johan Lindstrom, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
