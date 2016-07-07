use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Exception;

use autobox::Core;

use lib "lib";
use autobox::Transform;

subtest grep_each_basic => sub {
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep_each(),
        { one => 1, two => 2 },
        "grep_each with default 'true'",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep_each(sub { !! $_ }),
        { one => 1, two => 2 },
        "grep_each with subref 'true'",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep_each(sub { ($_ || 0) > 1 }),
        { two => 2 },
        "grep_each with subref using _",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep_each(sub { !! $_[1] }),
        { one => 1, two => 2 },
        "grep_each with value 'true'",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep_each(sub { $_[0] eq "one" }),
        { one => 1 },
        "grep_each with key eq",
    );
};

subtest grep_each_defined_basic => sub {
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep_each_defined(),
        { one => 1, two => 2, zero => 0 },
        "grep_each_defined",
    );
};


done_testing();
