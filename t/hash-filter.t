use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Exception;

use autobox::Core;

use lib "lib";
use autobox::Transform;

subtest filter_each_basic => sub {
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->filter_each(),
        { one => 1, two => 2 },
        "filter_each with default 'true'",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->filter_each(sub { !! $_ }),
        { one => 1, two => 2 },
        "filter_each with subref 'true'",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->filter_each(sub { ($_ || 0) > 1 }),
        { two => 2 },
        "filter_each with subref using _",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->filter_each(sub { !! $_[1] }),
        { one => 1, two => 2 },
        "filter_each with value 'true'",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->filter_each(sub { $_[0] eq "one" }),
        { one => 1 },
        "filter_each with key eq",
    );
};

subtest filter_each_defined_basic => sub {
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->filter_each_defined(),
        { one => 1, two => 2, zero => 0 },
        "filter_each_defined",
    );
};

subtest grep => sub {
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep_each(),
        { one => 1, two => 2 },
        "grep_each with default 'true'",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep_each_defined(),
        { one => 1, two => 2, zero => 0 },
        "grep_each_defined",
    );
};


done_testing();
