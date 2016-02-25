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

subtest group_by => sub {
    note "ArrayRef call, list context result";
    eq_or_diff(
        { $books->group_by("genre") },
        {
            "Sci-fi"  => 3,
            "Fantasy" => 1,
        },
        "Group by simple method call works",
    );

    note "list call, list context result";
    my @books = @$books;
    my $genre_exists = @books->group_by("genre");
    eq_or_diff(
        $genre_exists,
        {
            "Sci-fi"  => 3,
            "Fantasy" => 1,
        },
        "Group by simple method call works",
    );
};

subtest group_by__missing_method => sub {
    throws_ok(
        sub { $books->group_by() },
        qr{^->group_by\(\)[ ]missing[ ]argument:[ ]\$method \s at .+? t.group_by.t }x,
        "Missing arg croaks from the caller, not from the lib"
    )
};

subtest group_by__not_a_method => sub {
    # Invalid arg, not a method
    throws_ok(
        sub { $books->group_by("not_a_method") },
        qr{ not_a_method .+? Book .+? t.group_by.t }x,
        "Missing method croaks from the caller, not from the lib",
    )
};

subtest group_by__args => sub {
    eq_or_diff(
        { $authors->group_by(publisher_affiliation => ["with"]) },
        {
            'James A. Corey with Orbit'     => 1,
            'Cixin Liu with Head of Zeus'   => 1,
            'Patrick Rothfuss with Gollanz' => 1,
        },
        "group_by with argument list",
    );
};

subtest group_by__args__invalid_type => sub {
    throws_ok(
        sub { $authors->group_by(publisher_affiliation => 342) },
        qr{ group_by .+? 'publisher_affiliation' .+? \$args .+? \(342\) .+? array[ ]ref .+? t.group_by.t}x,
        "group_by with argument which isn't an array ref",
    )
};

subtest group_by__sub_ref => sub {
    eq_or_diff(
        { $books->group_by("genre", [], sub { 1 }) },
        {
            "Sci-fi"  => 1,
            "Fantasy" => 1,
        },
        "group_by with sub_ref works",
    );
};

subtest group_by__gather_sub => sub {
    my $genre_books = $books->group_by( "genre", undef, []->gather_sub );
    my $genre_book_titles = {
        map {
            $_ => $genre_books->{$_}->map_by("title")->sort->join(", ");
        }
        $genre_books->keys
    };

    eq_or_diff(
        $genre_book_titles,
        {
            "Sci-fi"  => "Caliban's War, Leviathan Wakes, The Tree-Body Problem",
            "Fantasy" => "The Name of the Wind",
        },
        "group_by with gather_sub work",
    );
};

subtest examples => sub {
    ok(1);
};




done_testing();
