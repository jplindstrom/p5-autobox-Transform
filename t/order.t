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

subtest order_simple => sub {
    my $expected = [
        "Caliban's War",
        "Leviathan Wakes",
        "The Name of the Wind",
        "The Tree-Body Problem",
    ];
    eq_or_diff(
        $books->map_by("title")->order->to_ref,
        $expected,
        "order default everything, scalar context",
    );
    eq_or_diff(
        [ $books->map_by("title")->order ],
        $expected,
        "order default everything, list context",
    );
};


done_testing();
