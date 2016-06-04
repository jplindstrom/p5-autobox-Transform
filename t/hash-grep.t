use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Exception;

use autobox::Core;

use lib "lib";
use autobox::Transform;

subtest grep_basic => sub {
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep(),
        { one => 1, two => 2 },
        "grep with default 'true'",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep(sub { !! $_ }),
        { one => 1, two => 2 },
        "grep with subref 'true'",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep(sub { ($_ || 0) > 1 }),
        { two => 2 },
        "grep with subref using _",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep(sub { !! $_[1] }),
        { one => 1, two => 2 },
        "grep with value 'true'",
    );
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep(sub { $_[0] eq "one" }),
        { one => 1 },
        "grep with key eq",
    );
};

subtest grep_defined_basic => sub {
    eq_or_diff(
        scalar { one => 1, zero => 0, two => 2, undefined => undef }->grep_defined(),
        { one => 1, two => 2, zero => 0 },
        "grep_defined",
    );
};


done_testing();
