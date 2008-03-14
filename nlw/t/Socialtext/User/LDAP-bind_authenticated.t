#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings FATAL => 'all';
use mocked 'Net::LDAP';
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 6;

# FIXTURE:  ldap_authenticated
#
# These tests specificially require that we're using an -authenticated- LDAP
# connection.
fixtures( 'ldap_authenticated' );
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
# LDAP "authenticated bind" is supported
ldap_authenticated_bind: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        bind_requires_authentication => 1,
        );
    clear_log();

    my $user = Socialtext::User::LDAP->new(username=>'First Last');
    isa_ok $user, 'Socialtext::User::LDAP', 'authenticated bind; found user';

    # VERIFY mocks
    my $mock = Net::LDAP->mocked_object();
    $mock->called_pos_ok( 1, 'bind' );
    my ($self, $dn, %opts) = $mock->call_args(1);
    ok defined $dn, 'authenticated bind; has username';
    ok exists $opts{'password'}, 'authenticated bind; has password';

    # VERIFY logs; should be empty
    is logged_count(), 0, '... logged right number of entries';
}
