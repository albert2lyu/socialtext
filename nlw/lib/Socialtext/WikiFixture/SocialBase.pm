package Socialtext::WikiFixture::SocialBase;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Account;
use Socialtext::User;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::JSON qw/decode_json encode_json/;
use Socialtext::File;
use Socialtext::System;
use Socialtext::HTTP::Ports;
use Socialtext::Role;
use File::LogReader;
use Test::More;
use Test::HTTP;
use Time::HiRes qw/gettimeofday tv_interval time/;
use URI::Escape qw(uri_unescape uri_escape);
use Data::Dumper;

=head1 NAME

Socialtext::WikiFixture::SocialBase - Base fixture class that has shared logic

=head2 init()

Creates the Test::HTTP object.

=cut

sub init {
    my $self = shift;

    # provide access to the default HTTP(S) ports in use
    $self->{http_port}          = Socialtext::HTTP::Ports->http_port();
    $self->{https_port}         = Socialtext::HTTP::Ports->https_port();
    $self->{backend_http_port}  = Socialtext::HTTP::Ports->backend_http_port();
    $self->{backend_https_port} = Socialtext::HTTP::Ports->backend_https_port();

    # Set up the Test::HTTP object initially
    $self->http_user_pass($self->{username}, $self->{password});
}

sub _munge_command_and_opts {
    my $self = shift;
    my $command = lc(shift);
    my @opts = $self->_munge_options(@_);
    $command =~ s/-/_/g;
    $command =~ s/^\*(.+)\*$/$1/;

    if ($command eq 'body_like') {
        $opts[0] = $self->quote_as_regex($opts[0]);
    }
    elsif ($command =~ m/_like$/) {
        $opts[1] = $self->quote_as_regex($opts[1]);
    }

    return ($command, @opts);
}

sub _handle_command {
    my $self = shift;
    my ($command, @opts) = @_;

    if (__PACKAGE__->can($command)) {
        return $self->$command(@opts);
    }
    if ($self->{http}->can($command)) {
        return $self->{http}->$command(@opts);
    }
    die "Unknown command for the fixture: ($command)\n";
}

=head2 http_user_pass ( $username, $password )

Set the HTTP username and password.

=cut

sub http_user_pass {
    my $self = shift;
    my $user = shift;
    my $pass = shift;

    my $name = ($self->{http}) ? $self->{http}->name : 'SocialRest fixture';

    $self->{http} = Test::HTTP->new($name);
    $self->{http}->username($user) if $user;
    $self->{http}->password($pass) if $pass;
}



=head2 follow_redirects_for ( $methods )

Choose which methods to follow redirects for.

Default: | follow_redirects_for | GET, HEAD |

Don't follow any redirects: | follow_redirects_for | |

=cut

sub follow_redirects_for {
    my $self    = shift;
    my $methods = shift || '';

    my @methods = map { uc } split m/\s*,\s*/, $methods;

    diag "Only following " . join ', ', @methods;
    $self->{http}->ua->requests_redirectable(\@methods);
}

=head2 big_db

Loads the database with records.  Configured through wiki 
variables as follows:

=over 4

=item db_accounts

=item db_users

=item db_pages

=item db_events

=item db_signals

=back

=cut

sub big_db {
    my $self = shift;
    my @args = map { ("--$_" => $self->{"db_$_"}) }
        grep { exists $self->{"db_$_"} }
        qw(accounts users pages events signals);

    Socialtext::System::shell_run('really-big-db.pl', @args);
}

=head2 stress_for <secs>

Run the stress test code for this many seconds.

=cut

sub stress_for {
    my $self = shift;
    my @args = map { ("--$_" => $self->{"torture_$_"}) }
        grep { exists $self->{"torture_$_"} }
        qw(signalsleep postsleep eventsleep background-sleep signalsclients postclients eventclients background-clients use-at get-avs server limit rampup followers sleeptime base users);

    Socialtext::System::shell_run('torture', @args);
}

=head2 standard_test_setup

Set up a new account, workspace and user to work with.

=cut

sub standard_test_setup {
    my $self = shift;
    my $prefix = shift || '';
    $prefix .= '_' if $prefix;
    my $acct_name = shift || "${prefix}acct-$self->{start_time}";
    my $wksp_name = shift || "${prefix}wksp-$self->{start_time}";
    my $user_name = shift || "${prefix}user-$self->{start_time}\@ken.socialtext.net";
    my $password  = shift || "${prefix}password";

    my $acct = $self->create_account($acct_name);
    my $wksp = $self->create_workspace($wksp_name, $acct_name);
    my $user = $self->create_user($user_name, $password, $acct_name);
    $self->add_workspace_admin($user_name, $wksp_name);

    $self->{"${prefix}account"} = $acct_name;
    $self->{"${prefix}account_id"} = $acct->account_id;
    $self->{"${prefix}workspace"} = $wksp_name;
    $self->{"${prefix}workspace_id"} = $wksp->workspace_id;
    $self->{"${prefix}email_address"} = $user_name;
    $self->{"${prefix}username"} = $user_name;
    $self->{"${prefix}user_id"} = $user->user_id;
    $self->{"${prefix}password"} = $password;
    $self->http_user_pass($user_name, $password);
}

sub create_account {
    my $self = shift;
    my $name = shift;
    my $acct = Socialtext::Account->create(
        name => $name,
    );
    my $ws = Socialtext::Workspace->new(name => 'admin');
    $acct->enable_plugin($_) for qw/people dashboard widgets signals/;
    $ws->enable_plugin($_) for qw/socialcalc/;
    diag "Created account $name";
    $self->{account_id} = $acct->account_id;
    return $acct;
}

sub dump_vars {
    my $self = shift;
    my %hash;
    for my $key (sort keys %$self) {
        next if ref $self->{$key};
        next unless defined $self->{$key};
        diag "Var '$key': $self->{$key}";
    }
}

sub account_config {
    my $self = shift;
    my $account_name = shift;
    my $key = shift;
    my $val = shift;
    my $acct = Socialtext::Account->new(
        name => $account_name,
    );
    $acct->update($key => $val);
    diag "Set account $account_name config: $key to $val";
}

sub get_account_id {
    my ($self, $name, $variable) = @_;
    my $acct = Socialtext::Account->new(name => $name);
    $self->{$variable} = $acct->account_id;
}

sub workspace_config {
    my $self = shift;
    my $ws_name = shift;
    my $key = shift;
    my $val = shift;
    my $ws = Socialtext::Workspace->new(
        name => $ws_name,
    );
    $ws->update($key => $val);
    diag "Set workspace $ws_name config: $key to $val";
}

sub disable_account_plugin {
    my $self = shift;
    my $account_name = shift;
    my $plugin = shift;

    my $acct = Socialtext::Account->new(
        name => $account_name,
    );
    $acct->disable_plugin($plugin);
    diag "Disabled plugin $plugin in account $account_name";
}

sub create_user {
    my $self = shift;
    my $email = shift;
    my $password = shift;
    my $account = shift;
    my $name = shift || ' ';
    my $username = shift || $email;

    my ($first_name,$last_name) = split(' ',$name,2);
    $first_name ||= '';
    $last_name ||= '';

    my $user = Socialtext::User->create(
        email_address => $email,
        username      => $username,
        password      => $password,
        first_name    => $first_name,
        last_name     => $last_name,
        (
            $account
            ? (primary_account_id =>
                    Socialtext::Account->new(name => $account)->account_id())
            : ()
        )
    );
    diag "Created user ".$user->email_address. ", name ".$user->guess_real_name;
    return $user;
}

sub create_workspace {
    my $self = shift;
    my $name = shift;
    my $account = shift;

    my $ws = Socialtext::Workspace->new(name => $name);
    if ($ws) {
        diag "Workspace $name already exists";
        return
    }

    $ws = Socialtext::Workspace->create(
        name => $name, title => $name,
        (
            $account
            ? (account_id => Socialtext::Account->new(name => $account)
                ->account_id())
            : (account_id => Socialtext::Account->Default->account_id())
        ),
        skip_default_pages => 1,
    );
    $ws->enable_plugin($_) for qw/socialcalc/;
    diag "Created workspace $name";
    return $ws;
}

sub purge_workspace {
    my $self = shift;
    my $name = shift;

    my $ws = Socialtext::Workspace->new(name => $name);
    unless ($ws) {
        die "Workspace $name doesn't already exist";
    }

    my $users = $ws->users;
    while (my $user = $users->next) {
        sql_execute('DELETE FROM users WHERE user_id = ? CASCADE',
            $user->user_id);
    }
    $ws->delete();
    diag "Workspace $name was purged, along with all users in that workspace.";
}

sub set_ws_permissions {
    my $self       = shift;
    my $workspace  = shift;
    my $permission = shift;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    die "No such workspace $workspace" unless $ws;
    $ws->permissions->set( set_name => $permission );
    diag "Set workspace $workspace permission to $permission";
}

sub add_member {
    my $self = shift;
    my $email = shift;
    my $workspace = shift;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    die "No such workspace $workspace" unless $ws;
    my $user = Socialtext::User->Resolve($email);
    die "No such user $email" unless $user;

    $ws->add_user( user => $user );
    diag "Added user $email to $workspace";
}

sub remove_member {
    my $self = shift;
    my $email = shift;
    my $workspace = shift;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    die "No such workspace $workspace" unless $ws;
    my $user = Socialtext::User->Resolve($email);
    die "No such user $email" unless $user;

    $ws->remove_user( user => $user );
    diag "Added user $email to $workspace";
}

sub add_workspace_admin {
    my $self = shift;
    my $email = shift;
    my $workspace = shift;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    die "No such workspace $workspace" unless $ws;
    my $user = Socialtext::User->Resolve($email);
    die "No such user $email" unless $user;

    $ws->add_user( 
        user => $user,
        role => Socialtext::Role->WorkspaceAdmin(),
    );
    diag "Added user $email to $workspace as admin";
}

sub set_business_admin {
    my $self = shift;
    my $email = shift;
    my $value = shift;

    my $user = Socialtext::User->Resolve($email);
    die "No such user $email" unless $user;

    $user->set_business_admin($value);
    diag "Set user $email is_business_admin to '$value'";
}

sub set_technical_admin {
    my $self = shift;
    my $email = shift;
    my $value = shift;

    my $user = Socialtext::User->Resolve($email);
    die "No such user $email" unless $user;

    $user->set_technical_admin($value);
    diag "Set user $email is_technical_admin to '$value'";
}

sub set_json_from_perl {
    my ($self, $name, $value) = @_;
    $self->{$name} = encode_json(eval $value);
    diag "Set $name to $self->{$name}";
}

sub set_json_from_string {
    my ($self, $name, $value) = @_;
    $self->{$name} = encode_json($value);
    diag "Set $name to $self->{$name}";
}

sub set_uri_escaped {
    my ($self, $name, $value) = @_;
    $self->{$name} = uri_escape($value);
    diag "Set $name to $self->{$name}";
}

sub set_user_id {
    my $self = shift;
    my $var_name = shift;
    my $email = shift;

    my $user = Socialtext::User->Resolve($email);
    die "No such user $email" unless $user;
    $self->{$var_name} = $user->user_id;
    diag "Set variable $var_name to $self->{$var_name}";
}

sub set_account_id {
    my $self = shift;
    my $var_name = shift;
    my $acct_name = shift;

    my $acct = Socialtext::Account->new(name => $acct_name);
    die "No such user $acct_name" unless $acct;
    $self->{$var_name} = $acct->account_id;
    diag "Set variable $var_name to $self->{$var_name}";
}

=head2 set_regex_escape( $varname, $value )

Takes a value and places a regex-escaped value in a variable that should be used 
for the value of a *like command.

This is convenient when you are constructing a string with / that needs escaping 
(the / needs escaping inside or outside of a qr//) for use with *like commands

=cut
sub set_regex_escaped {
    my $self = shift;
    my $var_name = shift;
    my $value = shift;

    #$value =~ s/\//\\\//;
    $self->{$var_name} = "\Q$value\E";
}

sub sleep {
    my $self = shift;
    my $secs = shift;
    sleep $secs;
}

=head2 get ( uri, accept )

GET a URI, with the specified accept type.  

accept defaults to 'text/html'.

=cut

sub get {
    my ($self, $uri, $accept) = @_;
    $accept ||= 'text/html';

    $self->_get($uri, [Accept => $accept]);
}

=head2 cond_get ( uri, accept, ims, inm )

GET a URI, specifying Accept, If-Modified-Since and If-None-Match headers.

Accept defaults to text/html.

The IMS and INS headers aren't sent unless specified and non-zero.

=cut

sub cond_get {
    my ($self, $uri, $accept, $ims, $inm) = @_;
    $accept ||= 'text/html';
    my @headers = ( Accept => $accept );
    push @headers, 'If-Modified-Since', $ims if $ims;
    push @headers, 'If-None-Match', $inm if $inm;

    warn "Calling get on $uri";
    my $start = time();
    $self->{http}->get($self->{browser_url} . $uri, \@headers);
    $self->{_last_http_time} = time() - $start;
}

sub was_faster_than {
    my ($self, $secs) = @_;

    my $elapsed = delete $self->{_last_http_time} || -1;
    cmp_ok $elapsed, '<=', $secs, "timer was faster than $secs";
}

=head2 delete ( uri, accept )

DELETE a URI, with the specified accept type.  

accept defaults to 'text/html'.

=cut

sub delete {
    my ($self, $uri, $accept) = @_;
    $accept ||= 'text/html';

    $self->_delete($uri, [Accept => $accept]);
}
            

=head2 code_is( code [, expected_message])

Check that the return code is correct.

=cut

sub code_is {
    my ($self, $code, $msg) = @_;
    $self->{http}->status_code_is($code);
    if ($self->{http}->response->code != $code) {
        warn "Response message: "
            . ($self->{http}->response->message || 'None')
            . " url(" . $self->{http}->request->url . ")";
    }
    if ($msg) {
        like $self->{http}->response->content(), $self->quote_as_regex($msg),
             "Status content matches";
    }
}

=head2 has_header( header [, expected_value])

Check that the specified header is in the response, with an optional second check for the header's value.

=cut

sub has_header {
    my ($self, $header, $value) = @_;
    my $hval = $self->{http}->response->header($header);
    ok $hval, "header $header is defined";
    if ($value) {
        like $hval, $self->quote_as_regex($value), "header content matches";
    }
}

=head2 post( uri, headers, body )

Post to the specified URI

=cut

sub post { shift->_call_method('post', @_) }

=head2 post_json( uri, body )

Post to the specified URI with header 'Content-Type=application/json'

=cut

sub post_json { 
    my $self = shift;
    my $uri = shift;
    $self->post($uri, 'Content-Type=application/json', @_);
}

=head2 post_form( uri, body )

Post to the specified URI with header 'Content-Type=application/x-www-form-urlencoded'

=cut

sub post_form {
    my $self = shift;
    my $uri = shift;
    $self->post($uri, 'Content-Type=application/x-www-form-urlencoded', @_);
}

=head2 put( uri, headers, body )

Put to the specified URI

=cut

sub put { shift->_call_method('put', @_) }

=head2 put_json( uri, json )

Put json to the specified URI

=cut

sub put_json {
    my $self = shift;
    my $uri = shift;
    $self->put($uri, 'Content-Type=application/json', @_);
}

=head2 put_sheet( uri, sheet_filename )

Put the contents of the specified file to the URI as a spreadsheet.

=cut

sub put_sheet {
    my $self     = shift;
    my $uri      = shift;
    my $filename = shift;

    my $dir = "t/wikitests/test-data/socialcalc";
    my $file = "$dir/$filename";
    die "Can't find spreadsheet at $file" unless -e $file;
    my $content = Socialtext::File::get_contents($file);
    my $json = encode_json({
        content => $content,
        type => 'spreadsheet',
    });

    $self->put($uri, 'Content-Type=application/json', $json);
}

=head2 set_http_keepalive ( on_off )

Enables/disables support for HTTP "Keep-Alive" connections (defaulting to I<off>).

When called, this method re-instantiates the C<Test::HTTP> object that is
being used for testing; be aware of this when writing your tests.

=cut

sub set_http_keepalive {
    my $self   = shift;
    my $on_off = shift;

    # switch User-Agent classes
    $Test::HTTP::UaClass = $on_off ? 'Test::LWP::UserAgent::keep_alive' : 'LWP::UserAgent';

    # re-instantiate our Test::HTTP object
    delete $self->{http};
    $self->http_user_pass($self->{username}, $self->{password});
}

=head2 set_from_content ( name, regex )

Set a variable from content in the last response.

=cut

sub set_from_content {
    my $self = shift;
    my $name = shift || die "name is mandatory for set-from-content";
    my $regex = $self->quote_as_regex(shift || '');
    my $content = $self->{http}->response->content;
    if ($content =~ $regex) {
        if (defined $1) {
            $self->{$name} = $1;
            warn "# Set $name to '$1' from response content\n";
        }
        else {
            die "Could not set $name - regex didn't capture!";
        }
    }
    else {
        die "Could not set $name - regex ($regex) did not match $content";
    }
}

=head2 set_from_header ( name, header )

Set a variable from a header in the last response.

=cut

sub set_from_header {
    my $self = shift;
    my $name = shift || die "name is mandatory for set-from-header";
    my $header = shift || die "header is mandatory for set-from-header";
    my $content = $self->{http}->response->header($header);

    if (defined $content) {
        $self->{$name} = $content;
        warn "# Set $name to '$content' from response header\n";
    }
    else {
        die "Could not set $name - header $header not present\n";
    }
}

=head2 st-clear-events

Delete all events

=cut

sub st_clear_events {
    sql_execute('DELETE FROM event');
}

=head2 st-clear-webhooks

Delete all webhooks.

=cut

sub st_clear_webhooks {
    sql_execute('DELETE FROM webhook');
}

=head2 st-clear-log

Clear any log lines.

=cut

sub st_clear_log {
    my $self = shift;
    my $lr = $self->_logreader;
    while ($lr->read_line) {}
}

sub _logreader {
    my $self = shift;
    return $self->{_logreader} ||= File::LogReader->new(
        filename  => "$ENV{HOME}/.nlw/log/nlw.log",
        state_dir => 't/tmp/wikitest-logreader.state',
    );
}


=head2 log-like

Checks that the nlw.log matches your expected output.

=cut

sub log_like {
    my $self = shift;
    my $expected = shift;

    my $log = '';
    my $lr = $self->_logreader;
    while(my $line = $lr->read_line) {
        $log .= "$line\n";
    }

    like $log, qr/$expected/, 'log-like';
}

=head2 st-clear-signals

Delete all signals

=cut

sub st_clear_signals {
    sql_execute("DELETE FROM signal");
}


=head2 st-delete-people-tags

Delete all people tags.

=cut

sub st_delete_people_tags {
    sql_execute('DELETE FROM tag_people__person_tags');
    sql_execute('DELETE FROM person_tag');
}

=head2 json-parse

Try to parse the body as JSON, remembering the result for additional tests.

=cut

sub json_parse {
    my $self = shift;
    $self->{json} = undef;
    $self->{json} = eval { decode_json($self->{http}->response->content) };
    ok !$@ && defined $self->{json} && ref($self->{json}) =~ /^ARRAY|HASH$/,
        $self->{http}->name . " parsed content" . ($@ ? " \$\@=$@" : "");
}

=head2 json-like

Confirm that the resulting body is a JSON object which is like (ignoring order
for arrays/dicts) the value given. 

The comparison is as follows between the 'candidate' given as a param in the
wikitest, and the value object derived from decoding hte json object from the
wikitest.  this is performed recursively): 1) if the value object is a scalar,
perform comparison with candidate (both must be scalars), 2) if the object is
an array, then for each object in the candidate, ensure the object in the is a
dictionary, then for each key in the candidate object, ensure that the same
key exists in the value object and that it maps to a value that is equivalent
to the value mapped to in the candidate object.

*WARNING* - Right now, this is stupid about JSON numbers as strings v.
numbers. That is, the values "3" and 3 are considered equivalent (e.g.
{"foo":3} and {"foo":"3"} are considered equivalent - this is a known bug in
this fixture)

=cut


sub json_like {
    
    my $self = shift;
    my $candidate = shift;

    my $json = $self->{json};
      
    if (not defined $json ) {
        fail $self->{http}->name . " no json result";
    }
    my $parsed_candidate = eval { decode_json($candidate) };
    if ($@ || ! defined $parsed_candidate || ref($parsed_candidate) !~ /^|ARRAY|HASH|SCALAR$/)  {
        fail $self->{http}->name . " failed to find or parse candidate " . ($@ ? " \$\@=$@" : "");
        return;
    }
    
    my $result=0;
    $result = eval {$self->_compare_json($parsed_candidate, $json)}; 
    if (!$@ && $result) {
        ok !$@ && $result, 
        $self->{http}->name . " compared content and candidate";
    } else {
        fail "$candidate\n and\n ".encode_json($json)."\n" . ($@ ? "\$\@=$@" : "");
    }
}

sub _compare_json {
    my $self = shift;
    my $candidate = shift;
    my $json = shift;


    die "Candidate is undefined" unless defined $candidate;
    die "JSON is undefined" unless defined $json;
    die encode_json($json) . " is not a VAL/SCALAR/HASH/ARRAY" unless ref($json) =~ /^|SCALAR|HASH|ARRAY$/;
    if (ref($json) eq 'SCALAR' || ref($json) eq '') {
        die "Type of $json and $candidate are not both values" unless (ref($json) eq ref($candidate));
        die "No match for \n$candidate\nAND\n$json\n" unless ($json eq $candidate);
    }
    elsif (ref($json) eq 'ARRAY') {
        my $match = 1;
        die "Expecting array for ". encode_json($candidate) . " with json ".encode_json($json) unless ref ($candidate) eq 'ARRAY'; 
        foreach (@$candidate) {
            my $candobj=$_;
            my $exists = 0;
            foreach (@$json) {
                $exists ||= eval {$self->_compare_json($candobj, $_)};
            }
            $match &&= $exists;
        }
        die "No match for candidate ".encode_json($candidate) . " with json ".encode_json($json) unless $match; 
    }
    elsif (ref($json) eq 'HASH') {
        die  "Expecting hash for ". encode_json($candidate) . " with json ".encode_json($json) unless ref($candidate) eq 'HASH'; 
        my $match = 1;
        for my $key (keys %$candidate) {
            die "Can't find value for key '$key' in JSON ". encode_json($json)  unless defined($json->{$key});
            $match &&= $self->_compare_json($candidate->{$key}, $json->{$key});
        }
        die "No match for candidate ".encode_json($candidate) . " with json ".encode_json($json) unless $match;
    }
}
=head2 json-array-size

Confirm that the resulting body is a JSON array of length X.

=cut

sub json_array_size {
    my $self = shift;
    my $comparator = shift;
    my $size = shift;

    if (!defined($size) or $size eq '') {
        $size = $comparator;
        $comparator = '==';
    }

    my $json = $self->{json};
    if (not defined $json ) {
        fail $self->{http}->name . " no json result";
    }
    elsif (ref($json) ne 'ARRAY') {
        fail $self->{http}->name . " json result is not an array";
    }
    else {
        cmp_ok scalar(@$json), $comparator, $size, 
            $self->{http}->name . " array is $comparator $size" ;
    }
}

sub _call_method {
    my ($self, $method, $uri, $headers, $body) = @_;
    if ($headers) {
        $headers = [
            map {
                my ($k,$v) = split m/\s*=\s*/, $_;
                $k =~ s/-/_/g;
                ($k,$v);
            } split m/\s*,\s*/, $headers
        ];
    }
    my $start = time();
    $self->{http}->$method($self->{browser_url} . $uri, $headers, $body);
    $self->{_last_http_time} = time() - $start;
}

sub _get {
    my ($self, $uri, $opts) = @_;
    warn "GET: $self->{browser_url}$uri\n"; # intentional warn
    my $start = time();
    $uri = "$self->{browser_url}$uri" if $uri =~ m#^/#;
    $self->{http}->get( $uri, $opts );
    $self->{_last_http_time} = time() - $start;
}

sub _delete {      
    my ($self, $uri, $opts) = @_;
    my $start = time();
    $self->{http}->delete( $self->{browser_url} . $uri, $opts );
    $self->{_last_http_time} = time() - $start;
}

sub edit_page {
    my $self = shift;
    my $workspace = shift;
    my $page_name = shift;
    my $content = shift;
    $self->put("/data/workspaces/$workspace/pages/$page_name",
        'Accept=text/html,Content-Type=text/x.socialtext-wiki',
        $content,
    );
    my $code = $self->{http}->response->code;
    ok( (($code == 201) or ($code == 204)), "Code is $code");
    diag "Edited page [$page_name]/$workspace";
}

=head2 st_deliver_email( )

Imitates sending an email to a workspace

=cut

sub deliver_email {
    my ($self, $workspace, $email_name) = @_;

    my $in = Socialtext::File::get_contents("t/test-data/email/$email_name");
    $in =~ s{^Subject: (.*)}{Subject: $1 $^T}m;

    my ($out, $err);
    my @command = ('bin/st-admin', 'deliver-email', '--workspace', $workspace);

    IPC::Run::run \@command, \$in, \$out, \$err;
    $self->{_deliver_email_result} = $? >> 8;
    $self->{_deliver_email_err} = $err;
    diag "Delivered $email_name email to the $workspace workspace";
}

sub deliver_email_result_is {
    my ($self, $result) = @_;
    is $self->{_deliver_email_result}, $result, 
        "Delivering email returns $result";
}

sub deliver_email_error_like {
    my ($self, $regex) = @_;
    $regex = $self->quote_as_regex($regex);
    like $self->{_deliver_email_err}, $regex, 
        "Delivering email stderr matches $regex";
}

sub set_from_json {
    my $self = shift;
    my $var  = shift;
    my $key  = shift;

    $self->{$var} = $self->{json}{$key};
}

sub set_from_header {
    my $self = shift;
    my $var  = shift;
    my $header = shift;

    $self->{$var} = $self->{http}->response->header($header);
}

sub set_from_subject {
    my $self = shift;
    my $name = shift || die "email-name is mandatory for set-from-email";
    my $email_name = shift || die "name is mandatory for set-from-email";
    my $in = Socialtext::File::get_contents("t/test-data/email/$email_name");
    if ($in =~ m{^Subject: (.*)}m) {
        ($self->{$name} = "$1 $^T") =~ s{^Re: }{};
    }
    else {
        die "Can't find subject in $email_name";
    }
}

sub remove_workspace_permission {
    my ($self, $workspace, $role, $permission) = @_;

    require Socialtext::Role;
    require Socialtext::Permission;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    my $perms = $ws->permissions;
    $perms->remove(
        role => Socialtext::Role->$role,
        permission => Socialtext::Permission->new( name => $permission ),
    );
    diag "Removed $permission permission for $workspace workspace $role role";
}

sub add_workspace_permission {
    my ($self, $workspace, $role, $permission) = @_;

    require Socialtext::Role;
    require Socialtext::Permission;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    my $perms = $ws->permissions;
    $perms->add(
        role => Socialtext::Role->$role,
        permission => Socialtext::Permission->new( name => $permission ),
    );
    diag "Added $permission permission for $workspace workspace $role role";
}

sub start_timer {
    my $self = shift;
    my $name = shift || 'default';

    $self->{_timer}{$name} = [ gettimeofday ];
}

sub faster_than {
    my $self = shift;
    my $ms = shift or die "faster_than requires a time in ms!";
    my $name = shift || 'default';
    my $start = $self->{_timer}{$name} || die "$name is not a valid timer!";

    my $elapsed = tv_interval($start);
    cmp_ok $elapsed, '<=', $ms, "$name timer was faster than $ms";
}

sub parse_logs {
    my $self = shift;
    my $file = shift;
    
    die "File doesn't exist!" unless -e $file;
    my $report_perl = "$^X -I$ENV{ST_CURRENT}/socialtext-reports/lib"
        . " -I$ENV{ST_CURRENT}/nlw/lib $ENV{ST_CURRENT}/socialtext-reports";
    Socialtext::System::shell_run("$report_perl/bin/st-reports-consume-access-log $file");
}

sub clear_reports {
    my $self = shift;
Socialtext::System::shell_run("cd $ENV{ST_CURRENT}/socialtext-reports; ./setup-dev-env");
}

=head2 header_isnt ( header, value )

Asserts that a header in the response does not contain the specified value.

=cut

sub header_isnt {
    my $self = shift;
    if ($self->{http}->can('header_isnt')) {
        return $self->{http}->header_isnt(@_);
    }
    else {
        my $header = shift;
        my $expected = shift;
        my $value = $self->{http}->response->header($header);
        isnt($value, $expected, "header $header");
    }
}

=head2 reset_plugins

Reset any global plugin enabled.

=cut

sub reset_plugins {
    my $self = shift;
    sql_execute(q{DELETE FROM "System" WHERE field like '%-enabled-all'});
}

=head2 st-clear-jobs

Clear out any queued jobs.

=cut

sub st_clear_jobs {
    Socialtext::System::shell_run('ceq-rm .');
    Socialtext::System::shell_run('-ceqlotron -f -o');
}

=head2 st-process-jobs

Run any queued jobs.

=cut

sub st_process_jobs {
    Socialtext::System::shell_run('-ceqlotron -f -o');
}


=head2 shell-run any-command and args

=cut

sub shell_run {
    my $self = shift;
    Socialtext::System::shell_run(join ' ', @_);
}

sub body_unlike {
    my ($self, $expected) = @_;
    my $body = $self->{http}->response->content;

    my $re_expected = $self->quote_as_regex($expected);
    unlike $body, $re_expected,
        $self->{http}->name() . " body-unlike $re_expected";
}

1;
