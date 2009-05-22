#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 22;
use Socialtext::AppConfig;

###############################################################################
# Fixtures: db
# - need a DB to work with, but don't care what's in it.
fixtures(qw( db ));

use_ok 'Socialtext::Group';

###############################################################################
# TEST: create Group
create_default_group: {
    Socialtext::AppConfig->set( 'group_factories', 'Default' );

    my $account_id = Socialtext::Account->Socialtext->account_id();
    my $creator_id = Socialtext::User->SystemUser->user_id();
    my $group = Socialtext::Group->Create( {
        driver_group_name   => 'Test Group',
        account_id          => $account_id,
        created_by_user_id  => $creator_id,
        } );
    isa_ok $group, 'Socialtext::Group', 'newly created group';
    isa_ok $group->homunculus, 'Socialtext::Group::Default',
        '... with Default homunculus';
}

###############################################################################
# TEST: retrieve Group
retrieve_default_group: {
    Socialtext::AppConfig->set( 'group_factories', 'Default' );

    my $account_id = Socialtext::Account->Socialtext->account_id();
    my $creator_id = Socialtext::User->SystemUser->user_id();
    my $group = Socialtext::Group->Create( {
        driver_group_name   => 'Test Group',
        account_id          => $account_id,
        created_by_user_id  => $creator_id,
        } );
    isa_ok $group, 'Socialtext::Group', 'newly created group';

    my $retrieved = Socialtext::Group->GetGroup(group_id => $group->group_id);
    isa_ok $retrieved, 'Socialtext::Group', 'retrieved group';
    isa_ok $retrieved->homunculus, 'Socialtext::Group::Default',
        '... with Default homunculus';

    is $retrieved->group_id, $group->group_id,
        '... with matching group_id';
    is $retrieved->driver_key, $group->driver_key,
        '... with matching driver_key';
    is $retrieved->driver_group_name, $group->driver_group_name,
        '... with matching driver_group_name';
    is $retrieved->account_id, $group->account_id,
        '... with matching account_id';
    is $retrieved->created_by_user_id, $group->created_by_user_id,
        '... with matching created_by_user_id';
    is $retrieved->creation_datetime, $group->creation_datetime,
        '... with matching creation_datetime';
}

###############################################################################
# TEST: update Group
update_default_group: {
    Socialtext::AppConfig->set( 'group_factories', 'Default' );

    my $account_id = Socialtext::Account->Socialtext->account_id();
    my $creator_id = Socialtext::User->SystemUser->user_id();
    my $group = Socialtext::Group->Create( {
        driver_group_name   => 'Test Group',
        account_id          => $account_id,
        created_by_user_id  => $creator_id,
        } );
    isa_ok $group, 'Socialtext::Group', 'newly created group';
    my $cached_at = $group->cached_at();

    my $new_account_id = Socialtext::Account->Unknown->account_id();
    my $new_creator_id = Socialtext::User->Guest->user_id();
    $group->update_store( {
        driver_group_name   => 'Updated Group Name',
        account_id          => $new_account_id,
        created_by_user_id  => $new_creator_id,
    } );

    is $group->driver_group_name, 'Updated Group Name',
        '... driver_group_name updated';
    is $group->account_id, $new_account_id,
        '... account_id updated';
    is $group->created_by_user_id, $new_creator_id,
        '... created_by_user_id updated';
    ok $group->cached_at->hires_epoch > $cached_at->hires_epoch,
        '... cached_at updated';

    my $refreshed = Socialtext::Group->GetGroup(group_id => $group->group_id);
    isa_ok $refreshed, 'Socialtext::Group', 'refreshed Group';

    is $refreshed->driver_group_name, 'Updated Group Name',
        '... with updated driver_group_name';
    is $refreshed->account_id, $new_account_id,
        '... with updated account_id';
    is $refreshed->created_by_user_id, $new_creator_id,
        '... with updated created_by_user_id';
    # XXX: should be ">" instead of "!=", but we lose hi-res resolution when
    #      the DateTime object is marshalled into the DB.
    ok $refreshed->cached_at->hires_epoch != $cached_at->hires_epoch,
        '... with updated cached_at';
}
