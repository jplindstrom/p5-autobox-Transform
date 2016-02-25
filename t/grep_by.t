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
my $authors    = $literature->{authors};

subtest grep_by => sub {
    note "ArrayRef call, list context result";
    eq_or_diff(
        [ map { $_->name } $authors->grep_by("is_prolific") ],
        [
            "James A. Corey",
        ],
        "grep_by simple method call works",
    );

    note "list call, list context result";
    my @authors = @$authors;
    my $prolific_authors = @authors->grep_by("is_prolific");
    eq_or_diff(
        [ map { $_->name } @$prolific_authors ],
        [
            "James A. Corey",
        ],
        "grep_by simple method call works",
    );
};

subtest examples => sub {
    my $prolific_author_book_titles = $authors->grep_by("is_prolific")
        ->map_by("books")->flat
        ->map_by("title")->sort;
    eq_or_diff(
        $prolific_author_book_titles,
        [
            "Caliban's War",
            "Leviathan Wakes"
        ],
        "prolific_author_book_titles",
    );
};




done_testing();
