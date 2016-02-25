use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Exception;

use autobox::Core;

use lib "lib";
use autobox::Transform;

use lib "t/lib";
use Literature;

my $literature = Literature::literature();
my $books      = $literature->{books};
my $authors    = $literature->{authors};

subtest map_by => sub {
    note "ArrayRef call, list context result";
    eq_or_diff(
        [ $books->map_by("genre") ],
        [
            "Sci-fi",
            "Sci-fi",
            "Sci-fi",
            "Fantasy",
        ],
        "Map by simple method call works",
    );

    note "list call, list context result";
    my @books = @$books;
    my $genres = @books->map_by("genre");
    eq_or_diff(
        $genres,
        [
            "Sci-fi",
            "Sci-fi",
            "Sci-fi",
            "Fantasy",
        ],
        "Map by simple method call works",
    );
};

subtest map_by__missing_method => sub {
    throws_ok(
        sub { $books->map_by() },
        qr{^->map_by\(\)[ ]missing[ ]argument:[ ]\$method \s at .+? t.map_by.t }x,
        "Missing arg croaks from the caller, not from the lib"
    )
};

subtest map_by__not_a_method => sub {
    # Invalid arg, not a method
    throws_ok(
        sub { $books->map_by("not_a_method") },
        qr{ not_a_method .+? Book .+? t.map_by.t }x,
        "Missing method croaks from the caller, not from the lib",
    )
};

subtest map_by__args => sub {
    eq_or_diff(
        [ $authors->map_by(publisher_affiliation => ["with"]) ],
        [
            'James A. Corey with Orbit',
            'Cixin Liu with Head of Zeus',
            'Patrick Rothfuss with Gollanz',
        ],
        "map_by with argument list",
    );
};

subtest map_by__args__invalid_type => sub {
    throws_ok(
        sub { $authors->map_by(publisher_affiliation => 342) },
        qr{ map_by .+? 'publisher_affiliation' .+? \$args .+? \(342\) .+? array[ ]ref .+? t.map_by.t}x,
        "map_by with argument which isn't an array ref",
    )
};


subtest examples => sub {

    my $tax_pct = 0.15;
    my $total_order_amount = $books
        ->map_by(price_with_tax => [ $tax_pct ])
        ->sum;
    is($total_order_amount, 28.75, "total_order_amount");


    my $order_authors = $books
        ->map_by("author")
        ->map_by("name")
        ->uniq->sort->join(", ");
    is(
        $order_authors,
        "Cixin Liu, James A. Corey, Patrick Rothfuss",
        "order_authors ok",
    )
};




done_testing();
