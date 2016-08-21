requires 'perl', '5.008001';

requires 'autobox';
requires 'autobox::Core';
requires 'true';
requires 'Carp';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Differences';
    requires 'Test::Exception';
    requires 'Moo';
};

