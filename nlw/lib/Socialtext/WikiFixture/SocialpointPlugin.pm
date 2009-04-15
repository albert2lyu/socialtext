# @COPYRIGHT@
package Socialtext::WikiFixture::SocialpointPlugin;
use strict;
use warnings;
use base 'Socialtext::WikiFixture::SocialRest';
use Socialtext::SQL qw/sql_singlevalue/;
use Socialtext::Pluggable::Plugin::Socialpoint;
use Test::More;

sub sp_password_is {
    my $self = shift;
    my $workspace_name = shift;
    my $expected_pw = shift;

    my $wksp_id = Socialtext::Workspace->new(name => $workspace_name)->workspace_id;
    my $crypted_pw = sql_singlevalue(<<EOT, $wksp_id);
SELECT value FROM workspace_plugin_pref
    WHERE workspace_id = ?
      AND plugin = 'socialpoint'
      AND key = 'password'
EOT

    my $got_pw = Socialtext::Pluggable::Plugin::Socialpoint::decrypt($crypted_pw);
    is $got_pw, $expected_pw, 'socialpoint password';
}

1;
