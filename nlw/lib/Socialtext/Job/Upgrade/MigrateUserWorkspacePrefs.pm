package Socialtext::Job::Upgrade::MigrateUserWorkspacePrefs;
# @COPYRIGHT@
use Moose;
use Socialtext::Paths;
use Socialtext::PreferencesPlugin;
use Socialtext::SQL qw/:exec/;
use Socialtext::Log qw/st_log/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;

    my $path = Socialtext::Paths::user_directory($self->workspace->name);
    my @files = glob("$path/*/preferences/preferences.dd");
    for my $f (@files) {
        (my $email = $f) =~ s#^.+/([^/]+)/preferences/preferences\.dd$#$1#;

        my $user = Socialtext::User->new(email_address => $email);
        if ($user) {
            $self->migrate_settings($user, $email);
        }

        unlink $f or warn "Could not unlink $f: $!";
        (my $pref_dir = $f) =~ s#/preferences\.dd$##;
        rmdir $pref_dir or warn "Could not rmdir $pref_dir: $!";
    }

    $self->completed();
}

sub migrate_settings {
    my $self  = shift;
    my $user  = shift;
    my $email = shift;

    my $is_in_db = sql_singlevalue('
        SELECT 1 FROM user_workspace_pref
         WHERE user_id = ? AND workspace_id = ?
         ', $user->user_id, $self->workspace->workspace_id,
    );
    return if $is_in_db;

    my $hub = $self->hub;
    $hub->current_user($user);

    # This will first load existing prefs, then save them to the DB
    eval {
        $hub->preferences->store($email, undef);
    };
    if ($@) {
        st_log->error("unable to import preferences for user ".
            "'$email' in workspace '".$self->workspace->name."'".
            ": $@");
    }
}

__PACKAGE__->meta->make_immutable;
1;