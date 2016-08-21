use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Exception;

use autobox::Core;

use lib "lib";
use autobox::Transform;

subtest "to_ref" => sub {
    my $array = [ 1, 2 ];
    my @array = @$array;
    eq_or_diff(
        [ @array->to_ref ],
        [ $array ],
        "Array to_ref in list contect works",
    );
    eq_or_diff(
        [ $array->to_ref ],
        [ $array ],
        "ArrayRef to_ref in list contect works",
    );
};

subtest "to_array" => sub {
    my $array = [ 1, 2 ];
    my @array = @$array;
    eq_or_diff(
        [ @array->to_array ],
        [ @array ],
        "Array to_array in list contect works",
    );
    eq_or_diff(
        [ $array->to_array ],
        [ @array ],
        "ArrayRef to_array in list contect works",
    );
};

subtest "to_hash" => sub {
    my $hash = { a => 1, b => 2 };
    my %hash = %$hash;
    eq_or_diff(
        { %hash->to_hash },
        { %hash },
        "Hash to_hash in list contect works",
    );
    eq_or_diff(
        { $hash->to_hash },
        { %hash },
        "HashRef to_hash in list contect works",
    );
};


done_testing();
