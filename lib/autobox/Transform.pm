package autobox::Transform;

use strict;
use warnings;
use 5.010;
use parent qw/autobox/;

our $VERSION = "1.022";

=head1 NAME

autobox::Transform - Autobox methods to transform Arrays and Hashes

=head1 CONTEXT

L<autobox> provides the ability to call methods on native types,
e.g. strings, arrays, and hashes as if they were objects.

L<autobox::Core> provides the basic methods for Perl core functions
like C<uc>, C<map>, and C<grep>.

This module, C<autobox::Transform>, provides higher level and more
specific methods to transform and manipulate arrays and hashes, in
particular when the values are hashrefs or objects.



=head1 SYNOPSIS

    use autobox::Core;  # uniq, sort, join, sum, etc.
    use autobox::Transform;

=head2 Arrays with hashrefs/objects

    # $books and $authors below are arrayrefs with either objects or
    # hashrefs (the call syntax is the same)

    $books->map_by("genre");
    $books->map_by([ price_with_tax => $tax_pct ]);

    $books->grep_by("is_sold_out");
    $books->grep_by([ is_in_library => $library ]);
    $books->grep_by([ price_with_tax => $rate ], sub { $_ > 56.00 });
    $books->grep_by("price", sub { $_ > 56.00 });

    $books->uniq_by("id");

    $books->group_by("title"),
    # {
    #     "Leviathan Wakes"       => $books->[0],
    #     "Caliban's War"         => $books->[1],
    #     "The Tree-Body Problem" => $books->[2],
    #     "The Name of the Wind"  => $books->[3],
    # },

    $authors->group_by([ publisher_affiliation => "with" ]),
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


=head2 Arrays

    # Flatten arrayrefs-of-arrayrefs
    $authors->map_by("books") # ->books returns an arrayref
    # [ [ $book1, $book2 ], [ $book3 ] ]
    $authors->map_by("books")->flat;
    # [ $book1, $book2, $book3 ]

    # Return reference, even in list context, e.g. in a parameter list
    report( genres => $books->map_by("genre")->to_ref );

    # Return array, even in scalar context
    @books->to_array;


=head2 Hashes

    # Upper-case the genre name, and make the count say "n books"
    $genre_count->map_each(sub { uc( $_[0] ) => "$_ books" });
    # {
    #     "FANTASY" => "1 books",
    #     "SCI-FI"  => "3 books",
    # },

    # Make the count say "n books"
    $genre_count->map_each_value(sub { "$_ books" });
    # {
    #     "Fantasy" => "1 books",
    #     "Sci-fi"  => "3 books",
    # },

    # Transform each pair to the string "n: genre"
    $genre_count->map_each_to_array(sub { "$_: $_[0]" });
    # [ "1: Fantasy", "3: Sci-fi" ]

    # Return reference, even in list context, e.g. in a parameter list
    %genre_count->to_ref );

    # Return hash, even in scalar context
    $author->book_count->to_hash;


=head2 Combined examples

    my $order_authors = $order->books
        ->uniq_by("isbn")
        ->map_by("author")
        ->map_by("name")->uniq->sort->join(", ");

    my $total_order_amount = $order->books
        ->grep_by([ not_covered_by_vouchers => $vouchers ])
        ->map_by([ price_with_tax => $tax_pct ])
        ->sum;



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

=item

$array->as_ref()

=item

$array->as_array()

=back


=over 4

=item

$hash->map_each

=item

$hash->map_each_value

=item

$hash->map_each_to_array

=item

$array->as_ref()

=item

$array->as_hash()

=back


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

# Normalize the two method calling styles for accessor + args:
#   $acessor, $args_arrayref, $modifier
# or
#   $acessor_and_args_arrayref, $modifier
sub _normalized_accessor_args_subref {
    my ($accessor, $args, $subref) = @_;

    # Note: unfortunately, this won't allow the $subref (modifier) to
    # become an arrayref later on when we do many types of modifiers
    # (string eq, qr regex match, sub call, arrayref in) for
    # filtering.
    #
    # That has to happen after the deprecation has expired and the old
    # syntax is removed.
    if(ref($args) eq "CODE") {
        $subref = $args; # Move down one step
        $args = undef;
    }
    if(ref($accessor) eq "ARRAY") {
        ($accessor, my @args) = @$accessor;
        $args = \@args;
    }

    return ($accessor, $args, $subref);
}



=head2 Transforming lists of objects vs list of hashrefs

C<map_by>, C<grep_by> etc. (all methods named C<*_by>) work with
arrays that contain hashrefs or objects.

These methods are called the same way regardless of whether the array
contains objects or hashrefs. The items in the list must all be either
objects or hashrefs.

If the array contains objects, a method is called on each object
(possibly with the arguments provided).

If the array contains hashrefs, the hash key is looked up on each
item.

=head3 Calling accessor methods with arguments

Consider C<grep_by>:

    $array->grep_by($accessor, $subref)

If the $accessor is a string, it's a simple lookup/method call.

    # method call without args
    $books->grep_by("price", sub { $_ < 15.0 })
    # becomes $_->price() or $_->{price}

If the $accessor is an arrayref, the first item is the method name,
and the rest of the items are the arguments to the method.

    # method call with args
    $books->grep_by([ price_with_discount => 5.0 ], sub { $_ < 15.0 })
    # becomes $_->price_with_discount(5.0)

=head3 Deprecated syntax

There is an older syntax for calling methods with arguments. It was
abandoned to open up more powerful ways to use grep/filter type
methods. Here it is for reference, in case you run into existing code.

    $array->grep_by($accessor, $args, $subref)
    $books->grep_by("price_with_discount", [ 5.0 ], sub { $_ < 15.0 })

Call the method $accessor on each object using the arguments in the
$args arrayref like so:

    $object->$accessor(@$args)

This style is deprecated, and planned for removal in version 2.000, so if
you have code with the old call style, please:

=over 4

=item

Replace your existing code with the new style as soon as possible. The
change is trivial and the code easily found by grep/ack.

=item

If need be, pin your version to < 2.000 in your cpanfile, dist.ini or
whatever you use to avoid upgrading to an incompatible version.

=back



=head2 List and Scalar Context

Almost all of the methods are context sensitive, i.e. they return a
list in list context and an arrayref in scalar context, just like
autobox::Core.

Beware: you might be in list context when you need an arrayref.

When in doubt, assume they work like C<map> and C<grep>, and convert
the return value to references where you might have an unobvious list
context. E.g.

    $self->my_method(
        # Wrong, this is list context and wouldn't return an arrayref
        books => $books->grep_by("is_published"),
    );

    $self->my_method(
        # Correct, convert the returned list to an arrayref
        books => [ $books->grep_by("is_published") ],
    );
    $self->my_method(
        # Correct, ensure scalar context to get an array ref
        books => scalar $books->grep_by("is_published"),
    );

    # Probably the nicest, since it goes at the end
    $self->my_method(
        # Correct, use ->to_ref to ensure an array reference is returned
        books => $books->grep_by("is_published")->to_ref,
    );



=head1 AUTOBOX ARRAY METHODS

=cut

package # hide from PAUSE
    autobox::Transform::Array;

use autobox::Core;

*_normalized_accessor_args_subref
    = \&autobox::Transform::_normalized_accessor_args_subref;

sub __invoke_by {
    my $invoke = shift;
    my $array = shift;
    my( $accessor, $args, $subref_name, $subref ) = @_;
    defined($accessor) or Carp::croak("->${invoke}_by() missing argument: \$accessor");
    @$array or return wantarray ? () : [ ];

    $args //= [];
    if ( ref($array->[0] ) eq "HASH" ) {
        ( defined($args) && (@$args) ) # defined and isn't empty
            and Carp::croak("${invoke}_by('$accessor'): \$args ($args) only supported for method calls, not hash key access");
        $invoke .= "_key";
    }

    ref($args) eq "ARRAY"
        or Carp::croak("${invoke}_by('$accessor', \$args): \$args ($args) is not an array ref");

    if( $subref_name ) {
        ref($subref) eq "CODE"
            or Carp::croak("${invoke}_by('$accessor', \$args, \$$subref_name): \$$subref_name ($subref) is not an sub ref");
    }

    my %seen;
    my $invoke_sub = {
        map      => sub { [ CORE::map  { $_->$accessor( @$args ) } @$array ] },
        map_key  => sub { [ CORE::map  { $_->{$accessor}         } @$array ] },
        grep     => sub { [ CORE::grep { $subref->( local $_ = $_->$accessor( @$args ) ) } @$array ] },
        grep_key => sub { [ CORE::grep { $subref->( local $_ = $_->{$accessor}         ) } @$array ] },
        uniq     => sub { [ CORE::grep { ! $seen{ $_->$accessor( @$args ) // "" }++ } @$array ] },
        uniq_key => sub { [ CORE::grep { ! $seen{ $_->{$accessor}         // "" }++ } @$array ] },
    }->{$invoke};

    my $result = eval { $invoke_sub->() }
        or autobox::Transform::throw($@);

    return wantarray ? @$result : $result;
}

=head2 @array->map_by($accessor) : @array | @$array

$accessor is either a string, or an arrayref where the first item is a
string.

Call the $accessor on each object in @array, or get the hash key value
on each hashref in @array. Like:

    map { $_->$accessor() }
    # or
    map { $_->{$accessor} }

Examples:

    my @ahthor_names = $authors->map_by("name");
    my $author_names = @publishers->map_by("authors")->map_by("name");

Or get the hash key value. Example:

    my @review_scores = $reviews->map_by("score");

Alternatively the $accessor is an arrayref. The first item is the
accessor name, and the rest of the items are passed as args the method
call. This only works when working with objects, not with hashrefs.

Examples:

    my @prices_including_tax = $books->map_by([ "price_with_tax", $tax_pct ]);
    my $prices_including_tax = $books->map_by([ price_with_tax => $tax_pct ]);

=cut

sub map_by {
    my $array = shift;
    my ($accessor, $args) = _normalized_accessor_args_subref(@_);
    return __invoke_by("map", $array, $accessor, $args);
}



=head2 @array->grep_by($accessor, $grep_subref = *is_true*) : @array | @$array

$accessor is either a string, or an arrayref where the first item is a
string.

Call the $accessor on each object in the list, or get the hash key
value on each hashref in the list. The default $grep_subref includes
true values in the result @array.

Examples:

    my @prolific_authors = $authors->grep_by("is_prolific");

Alternatively the $accessor is an arrayref. The first item is the
accessor name, and the rest of the items are passed as args the method
call. This only works when working with objects, not with hashrefs.

Examples:

    my @books_to_charge_for = $books->grep_by([ price_with_tax => $tax_pct ]);


=head3 The $grep_subref

The $grep_subref is called with the value returned from the $accessor
to check whether this item should remain in the list (default is to
check for true values).

The $grep_subref should return a true value to remain. $_ is set to
the current $value.

Examples:

    my @authors = $authors->grep_by(
        "publisher",
        sub { $_->name =~ /Orbit/ },
    );

    my @authors = $authors->grep_by(
        [ publisher_affiliation => "with" ],
        sub { /Orbit/ },
    );

Note: if you do something complicated with the $grep_subref, it might
be easier and more readable to simply use C<$array-$<gt>grep()> from
L<autobox::Core>.

=cut

sub grep_by {
    my $array = shift;
    my ($accessor, $args, $grep_subref) = _normalized_accessor_args_subref(@_);
    $grep_subref //= sub { !! $_ };
    # grep_by $value, if passed the method value must match the value?
    return __invoke_by(
        "grep",
        $array,
        $accessor,
        $args,
        grep_subref => $grep_subref,
    );
}

=head2 @array->uniq_by($accessor) : @array | @$array

$accessor is either a string, or an arrayref where the first item is a
string.

Call the $accessor on each object in the list, or get the hash key
value on each hashref in the list. Return list of items wich have a
unique set of return values. The order is preserved. On duplicates,
keep the first occurrence.

Examples:

    # You have gathered multiple Author objects with duplicate ids
    my @authors = $authors->uniq_by("author_id");

Alternatively the $accessor is an arrayref. The first item is the
accessor name, and the rest of the items are passed as args the method
call. This only works when working with objects, not with hashrefs.

Examples:

    my @example_book_at_price_point = $books->uniq_by(
        [ price_with_tax => $tax_pct ],
    );

=cut

sub uniq_by {
    my $array = shift;
    my ($accessor, $args) = _normalized_accessor_args_subref(@_);
    return __invoke_by("uniq", $array, $accessor, $args);
}



=head2 @array->group_by($accessor, $value_subref = object) : %key_value | %$key_value

$accessor is either a string, or an arrayref where the first item is a
string.

Call C<-E<gt>$accessor> on each object in the array, or get the hash
key for each hashref in the array (just like C<-E<gt>map_by>) and
group the values as keys in a hashref.

The default $value_subref puts each object in the list as the hash
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

=head3 The $value_subref

This is a bit tricky to use, so the most common thing would probably
be to use one of the more specific group_by-methods (see below). It
should be capable enough to achieve what you need though, so here's
how it works:

The hash key is whatever is returned from C<$object-E<gt>$accessor>.

The hash value is whatever is returned from

    my $new_value = $value_sub->($current_value, $object, $key);

where:

=over 4

=item

C<$current> value is the current hash value for this key (or undef if the first one).

=item

C<$object> is the current item in the list. The current $_ is also set to this.

=item

C<$key> is the key returned by $object->$accessor(@$args)

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
    my ($accessor, $args, $value_sub) = _normalized_accessor_args_subref(@_);

    $value_sub //= sub { $_ };
    ref($value_sub) eq "CODE"
        or Carp::croak("group_by('$accessor', [], \$value_sub): \$value_sub ($value_sub) is not a sub ref");

    return __core_group_by("group_by", $array, $accessor, $args, $value_sub);
}

=head2 @array->group_by_count($accessor) : %key_count | %$key_count

$accessor is either a string, or an arrayref where the first item is a
string.

Just like C<group_by>, but the hash values are the the number of
instances each $accessor value occurs in the list.

Example:

    $books->group_by_count("genre"),
    # {
    #     "Sci-fi"  => 3,
    #     "Fantasy" => 1,
    # },

C<$book-E<gt>genre()> returns the genre string. There are three books
counted for the "Sci-fi" key.

=cut

sub group_by_count {
    my $array = shift;
    my ($accessor, $args) = _normalized_accessor_args_subref(@_);

    my $value_sub = sub {
        my $count = shift // 0; return ++$count;
    };

    return __core_group_by("group_by_count", $array, $accessor, $args, $value_sub);
}

=head2 @array->group_by_array($accessor) : %key_objects | %$key_objects

$accessor is either a string, or an arrayref where the first item is a
string.

Just like C<group_by>, but the hash values are arrayrefs containing
the objects which has each $accessor value.

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
    my ($accessor, $args) = _normalized_accessor_args_subref(@_);

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

This is useful if e.g. a C<-E<gt>map_by("some_method")> returns
arrayrefs of objects which you want to do further method calls
on. Example:

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

=head2 @array->to_ref() : $arrayref

Return the reference to the @array, regardless of context.

Useful for ensuring the last array method return a reference while in
scalar context. Typically:

    do_stuff(
        books => $author->map_by("books")->to_ref,
    );

map_by is called in list context, so without ->to_ref it would have
return an array, not an arrayref.

=cut

sub to_ref {
    my $array = shift;
    return $array;
}

=head2 @array->to_array() : @array

Return the @array, regardless of context. This is mostly useful if
called on a ArrayRef at the end of a chain of method calls.

=cut

sub to_array {
    my $array = shift;
    return @$array;
}



=head1 AUTOBOX HASH METHODS

=cut

package # hide from PAUSE
    autobox::Transform::Hash;

use autobox::Core;

*_normalized_accessor_args_subref
    = \&autobox::Transform::_normalized_accessor_args_subref;



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



=head2 %hash->map_each($key_value_subref) : %new_hash | %$new_hash

Map each key-value pair in the hash using the
$key_value_subref. Similar to how to how map transforms a list into
another list, map_each transforms a hash into another hash.

C<$key_value_subref-E<gt>($key, $value)> is called for each pair (with
$_ set to the value).

The subref should return an even-numbered list with zero or more
key-value pairs which will make up the %new_hash. Typically two items
are returned in the list (the key and the value).

=head3 Example

    { a => 1, b => 2 }->map_each(sub { "$_[0]$_[0]" => $_ * 2 });
    # Returns { aa => 2, bb => 4 }

=cut

sub map_each {
    my $hash = shift;
    my ($key_value_subref) = @_;
    $key_value_subref //= "";
    ref($key_value_subref) eq "CODE"
        or Carp::croak("map_each(\$key_value_subref): \$key_value_subref ($key_value_subref) is not a sub ref");
    my $new_hash = {
        map { ## no critic
            my $key = $_;
            my $value = $hash->{$key};
            {
                local $_ = $value;
                my (@new_key_value) = $key_value_subref->($key, $value);
                (@new_key_value % 2) and Carp::croak("map_each \$key_value_subref returned odd number of keys/values");
                @new_key_value;
            }
        }
        keys %$hash,
    };

    return wantarray ? %$new_hash : $new_hash;
}

=head2 %hash->map_each_value($value_subref) : %new_hash | %$new_hash

Map each value in the hash using the $value_subref, but keep the keys
the same.

C<$value_subref-E<gt>($key, $value)> is called for each pair (with $_
set to the value).

The subref should return a single value for each key which will make
up the %new_hash (with the same keys but with new mapped values).

=head3 Example

    { a => 1, b => 2 }->map_each_value(sub { $_ * 2 });
    # Returns { a => 2, b => 4 }

=cut

sub map_each_value {
    my $hash = shift;
    my ($value_subref) = @_;
    $value_subref //= "";
    ref($value_subref) eq "CODE"
        or Carp::croak("map_each_value(\$value_subref): \$value_subref ($value_subref) is not a sub ref");
    my $new_hash = {
        map { ## no critic
            my $key = $_;
            my $value = $hash->{$key};
            {
                local $_ = $value;
                my @new_values = $value_subref->($key, $value);
                @new_values > 1 and Carp::croak(
                    "map_each_value \$value_subref returned multiple values. "
                    . "You can not assign a list to the value of hash key ($key). "
                    . "Did you mean to return an arrayref?",
                );
                $key => @new_values;
            }
        }
        keys %$hash,
    };

    return wantarray ? %$new_hash : $new_hash;
}

=head2 %hash->map_each_to_array($item_subref) : @new_array | @$new_array

Map each key-value pair in the hash into a list using the
$item_subref.

C<$item_subref-E<gt>($key, $value)> is called for each pair (with $_
set to the value) in key order.

The subref should return zero or more list items which will make up
the @new_array. Typically one item is returned.

=head3 Example

    { a => 1, b => 2 }->map_each_to_array(sub { "$_[0]-$_" });
    # Returns [ "a-1", "b-2" ]

=cut

sub map_each_to_array {
    my $hash = shift;
    my ($array_item_subref) = @_;
    $array_item_subref //= "";
    ref($array_item_subref) eq "CODE"
        or Carp::croak("map_each_to_array(\$array_item_subref): \$array_item_subref ($array_item_subref) is not a sub ref");
    my $new_array = [
        map { ## no critic
            my $key = $_;
            my $value = $hash->{$key};
            {
                local $_ = $value;
                $array_item_subref->($key, $value);
            }
        }
        sort keys %$hash,
    ];

    return wantarray ? @$new_array : $new_array;
}



sub grep_each {
    my $hash = shift;
    my ($subref) = @_;
    $subref ||= sub { !! $_ }; # true?

    my $new_hash = {
        map { ## no critic
            my $key = $_;
            my $value = $hash->{$key};
            {
                local $_ = $value;
                $subref->($key, $value)
                    ? ( $key => $value )
                    : ();
            }
        }
        keys %$hash,
    };

    return wantarray ? %$new_hash : $new_hash;
}
*grep = \&grep_each;

sub grep_each_defined {
    my $hash = shift;
    return &grep($hash, sub { defined($_) });
}
{
    no warnings "once";
    *grep_defined = \&grep_each_defined;
}


=head2 %hash->to_ref() : $hashref

Return the reference to the %hash, regardless of context.

Useful for ensuring the last hash method return a reference while in
scalar context. Typically:

    do_stuff(
        genre_count => $books->group_by_count("genre")->to_ref,
    );

=cut

sub to_ref {
    my $hash = shift;
    return $hash;
}

=head2 %hash->to_hash() : %hash

Return the %hash, regardless of context. This is mostly useful if
called on a HashRef at the end of a chain of method calls.

=cut

sub to_hash {
    my $hash = shift;
    return %$hash;
}



=head1 AUTOBOX AND VANILLA PERL


=head2 Raison d'etre

L<autobox::Core> is awesome, for a variety of reasons.

=over 4

=item

It cuts down on dereferencing punctuation clutter, both by using
methods on references and by using ->elements to deref arrayrefs.

=item

It makes map and grep transforms read in the same direction it's
executed.

=item

It makes it easier to write those things in a natural order. No need
to move the cursor around a lot just to fix dereferencing, order of
operations etc.

=back

On top of this, L<autobox::Transform> provides a few higher level
methods for mapping, filtering and sorting common cases which are easier
to read and write.

Since they are at a slightly higher semantic level, once you know them
they also provide a more specific meaning than just "map" or "grep".

(Compare the difference between seeing a "map" and seeing a "foreach"
loop. Just seeing the word "map" hints at what type of thing is going
on here: transforming a list into another list).

The methods of autobox::Transform are not suitable for all
cases, but when used appropriately they will lead to much more clear,
succinct and direct code, especially in conjunction with
autobox::Core.


=head2 Code Comparison

These examples are only for when there's a straightforward and simple
Perl equivalent.

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
        ->map_by([ price_with_tax => $tax_pct ])->sum;

    ### map_by - hash key: $books are book hashrefs
    my @genres = map { $_->{genre} } @$books;
    my @genres = $books->map_by("genre");



    ### grep_by - method call: $books are Book objects
    my $sold_out_books = [ grep { $_->is_sold_out } @$books ];
    my $sold_out_books = $books->grep_by("is_sold_out");

    my $books_in_library = [ grep { $_->is_in_library($library) } @$books ];
    my $books_in_library = $books->grep_by([ is_in_library => $library ]);

    ### grep_by - hash key: $books are book hashrefs
    my $sold_out_books = [ grep { $_->{is_sold_out} } @$books ];
    my $sold_out_books = $books->grep_by("is_sold_out");



    ### uniq_by - method call: $books are Book objects
    my %seen; my $distinct_books = [ grep { ! %seen{ $_->id // "" }++ } @$books ];
    my $distinct_books = $books->uniq_by("id");

    ### uniq_by - hash key: $books are book hashrefs
    my %seen; my $distinct_books = [ grep { ! %seen{ $_->{id} // "" }++ } @$books ];
    my $distinct_books = $books->uniq_by("id");


    #### flat - $author->books returns an arrayref of Books
    my $author_books = [ map { @{$_->books} } @$authors ]
    my $author_books = $authors->map_by("books")->flat



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
