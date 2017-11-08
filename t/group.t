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
my $reviews    = $literature->{reviews};

my $titles = $books->map_by("title")->order;

subtest group => sub {
    note "Basic group";

    my $book_title__title = {
        "Leviathan Wakes"       => "Leviathan Wakes",
        "Caliban's War"         => "Caliban's War",
        "The Tree-Body Problem" => "The Tree-Body Problem",
        "The Name of the Wind"  => "The Name of the Wind",
    };
    eq_or_diff(
        { $titles->group },
        $book_title__title,
        "List context, basic group works",
    );

    note "list call, list context result";
    my @titles = @$titles;
    my $title_exists = @titles->group;
    eq_or_diff(
        $title_exists,
        $book_title__title,
        "Group by simple method call works",
    );
};

# subtest group_count => sub {
#     note "ArrayRef call, list context result";

#     my $genre_count = {
#         "Sci-fi"  => 3,
#         "Fantasy" => 1,
#     };

#     eq_or_diff(
#         { $books->group_count("genre") },
#         $genre_count,
#         "Group by simple method call works",
#     );

#     note "list call, list context result";
#     my @books = @$books;
#     my $genre_exists = @books->group_count("genre");
#     eq_or_diff(
#         $genre_exists,
#         $genre_count,
#         "Group by simple method call works",
#     );
# };



# subtest group__sub_ref => sub {
#     eq_or_diff(
#         { $books->group("genre", [], sub { 1 }) },
#         {
#             "Sci-fi"  => 1,
#             "Fantasy" => 1,
#         },
#         "group with sub_ref works",
#     );
#     eq_or_diff(
#         { $books->group([ "genre" ], sub { 1 }) },
#         {
#             "Sci-fi"  => 1,
#             "Fantasy" => 1,
#         },
#         "group with sub_ref works",
#     );
# };

# subtest group__array => sub {
#     my $genre_books = $books->group_array("genre");
#     my $genre_books2 = $books->group_array([ "genre" ]);
#     eq_or_diff($genre_books, $genre_books2, "Same output");

#     my $genre_book_titles = {
#         map {
#             $_ => $genre_books->{$_}->map_by("title")->sort->join(", ");
#         }
#         $genre_books->keys
#     };

#     eq_or_diff(
#         $genre_book_titles,
#         {
#             "Sci-fi"  => "Caliban's War, Leviathan Wakes, The Tree-Body Problem",
#             "Fantasy" => "The Name of the Wind",
#         },
#         "group_array work",
#     );
# };

# subtest examples => sub {
#     ok(1);
# };




done_testing();
