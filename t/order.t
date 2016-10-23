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
my $books      = $literature->{books};

my $expected_titles_str = [
    "Caliban's War",
    "Leviathan Wakes",
    "The Name of the Wind",
    "The Tree-Body Problem",
];

my $expected_prices_asc = [ 5, 6, 6, 11 ];

subtest order_simple => sub {
    eq_or_diff(
        $books->map_by("title")->order->to_ref,
        $expected_titles_str,
        "order default everything, scalar context",
    );
    eq_or_diff(
        [ $books->map_by("title")->order ],
        $expected_titles_str,
        "order default everything, list context",
    );
};

subtest order_num_str => sub {
    eq_or_diff(
        $books->map_by("price")->order("num")->to_ref,
        $expected_prices_asc,
        "order num",
    );
    eq_or_diff(
        $books->map_by("title")->order("str")->to_ref,
        $expected_titles_str,
        "order str",
    );
};


done_testing();
