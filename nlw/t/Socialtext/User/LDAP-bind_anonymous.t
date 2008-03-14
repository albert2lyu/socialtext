#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings FATAL => 'all';
use mocked 'Net::LDAP';
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 8;

# FIXTURE:  ldap_anonymous
#
# These tests specifically require that we're using an anonymous LDAP
# connection.
fixtures( 'ldap_anonymous' );
use_ok 'Socialtext::User::LDAP';

###############################################################################
### TEST DATA
###############################################################################
my @TEST_USERS = (
    { dn            => 'cn=First Last,dc=example,dc=com',
      cn            => 'First Last',
      authPassword  => 'abc123',
      gn            => 'First',
      sn            => 'Last',
      mail          => 'user@example.com',
    },
    { dn            => 'cn=Another User,dc=example,dc=com',
      cn            => 'Another User',
      authPassword  => 'def987',
      gn            => 'Another',
      sn            => 'User',
      mail          => 'user@example.com',
    },
);

###############################################################################
# LDAP "anonymous bind" is supported
ldap_anonymous_bind: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        );
    clear_log();

    my $user = Socialtext::User::LDAP->new(username=>'First Last');
    isa_ok $user, 'Socialtext::User::LDAP', 'anonymous bind; found user';

    # VERIFY mocks
    my $mock = Net::LDAP->mocked_object();
    $mock->called_pos_ok( 1, 'bind' );
    my ($self, $dn, %opts) = $mock->call_args(1);
    ok !defined $dn, 'anonymous bind; no username';
    ok !exists $opts{'password'}, 'anonymous bind; no password';

    # VERIFY logs; should be empty
    is logged_count(), 0, '... logged right number of entries';
}

###############################################################################
# Instantiation with missing authentication returns empty handed.
instantiation_bind_requires_additional_auth: {
    Net::LDAP->set_mock_behaviour(
        bind_requires_authentication => 1,
        );
    clear_log();

    my $user = Socialtext::User::LDAP->new(username=>'First Last');
    ok !defined $user, 'instantiation w/bind requires additional auth';

    # VERIFY logs; make sure we failed for the right reason
    logged_like 'error', qr/unable to bind/, '... logged bind failure';
}
