#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 9;

###############################################################################
# Fixtures: db
# - need a DB, but don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::Role';

###############################################################################
# TEST: Get all Roles in the system
get_all_roles: {
    my $cursor = Socialtext::Role->All();
    isa_ok $cursor, 'Socialtext::MultiCursor', 'list of all Roles';

    # we've got *some* Roles created; don't care what they are yet, just so
    # long as we've got some.
    ok $cursor->count, '... containing some actual Roles';
}

###############################################################################
# TEST: Get all Roles, ordered by effectiveness
get_all_roles_ordered_by_effectiveness: {
    my $cursor = Socialtext::Role->AllOrderedByEffectiveness();
    isa_ok $cursor, 'Socialtext::MultiCursor', 'ordered list of Roles';

    # make sure the Roles are returned in the right order
    my @role_names    = map { $_->name } $cursor->all();
    my @default_order = Socialtext::Role->DefaultRoleNames;
    is_deeply \@role_names, \@default_order,
        '... Roles were returned in the default sorted order';
}

###############################################################################
# TEST: Get all Roles, ordered by effectiveness, with custom Roles present
get_all_roles_ordered_by_effectiveness_with_custom_roles: {
    my $custom_role_one = Socialtext::Role->create(name => 'ZZZ Role');
    isa_ok $custom_role_one, 'Socialtext::Role', 'first test Role';

    my $custom_role_two = Socialtext::Role->create(name => 'AAA Role');
    isa_ok $custom_role_two, 'Socialtext::Role', 'second test Role';

    # get the list of Roles
    my $cursor = Socialtext::Role->AllOrderedByEffectiveness();
    isa_ok $cursor, 'Socialtext::MultiCursor', 'ordered list of Roles';

    # make sure the Roles are returned in the right order
    my @role_names     = map { $_->name } $cursor->all();
    my @expected_order = (
        'AAA Role',                             # custom Roles alphabetically
        'ZZZ Role',
        Socialtext::Role->DefaultRoleNames,     # then built-in Roles
    );
    is_deeply \@role_names, \@expected_order,
        '... Roles were returned in the expected sorted order';
}
