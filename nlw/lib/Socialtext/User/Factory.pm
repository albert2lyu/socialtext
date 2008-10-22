package Socialtext::User::Factory;
# @COPYRIGHT@
use strict;
use warnings;

use Class::Field qw(field);
use Socialtext::SQL qw(:exec :time);
use Socialtext::SQL::Builder qw(:all);
use Socialtext::User::Cache;
use Readonly;
use Time::HiRes ();

# All fields/attributes that a "Socialtext::User::Base" has.
# These fields are used to export the user.
Readonly our @fields => qw(
    user_id
    username
    email_address
    first_name
    last_name
    password
);

# additional fields, not exported
Readonly our @other_fields => qw(
    driver_key
    driver_unique_id
    cached_at
);

Readonly our @all_fields => (@fields, @other_fields);

field 'driver_name';
field 'driver_id';
field 'driver_key';

sub new_homunculus {
    my $self = shift;
    my $p = shift;
    $p->{driver_key} = $self->driver_key;
    return $self->NewHomunculus($p);
}

sub get_homunculus {
    my $self = shift;
    my $id_key = shift;
    my $id_val = shift;
    return $self->GetHomunculus($id_key, $id_val, $self->driver_key);
}

sub NewHomunculus {
    my $class = shift;
    my $p = shift;

    # create a copy of the parameters for our new User homunculus object
    my %user = map { $_ => $p->{$_} } @all_fields;

    die "homunculi need to have a user_id, driver_key and driver_unique_id"
        unless ($user{user_id} && $user{driver_key} && $user{driver_unique_id});

    # bless the user object to the right class
    my ($driver_name, $driver_id) = split( /:/, $p->{driver_key} );
    require Socialtext::User;
    my $driver_class = join '::', Socialtext::User->base_package, $driver_name;
    eval "require $driver_class";
    die "Couldn't load ${driver_class}: $@" if $@;

    my $homunculus = $driver_class->new(\%user);

    # Remove password fields for users, where the password is over-ridden by
    # the User driver (Default, LDAP, etc) and where the resulting password is
    # *NOT* of any use.  No point keeping a bunk/bogus/useless password
    # around.
    if ($homunculus->password eq '*no-password*') {
        if ($p->{password} && ($p->{password} ne $homunculus->password)) {
            delete $homunculus->{password};
        }
    }

    # return the new homunculus; we're done.
    return $homunculus;
}

sub NewUserId {
    return sql_nextval('users___user_id');
}

sub ResolveId {
    my $class = shift;
    my $p = shift;
    my $user_id = sql_singlevalue(
        q{SELECT user_id FROM users 
          WHERE driver_key = ? AND driver_unique_id = ?},
        $p->{driver_key},
        $p->{driver_unique_id}
    );
}

sub Now {
    return DateTime->from_epoch(epoch => Time::HiRes::time());
}

sub GetHomunculus {
    my $class = shift;
    my $id_key = shift;
    my $id_val = shift;
    my $driver_key = shift;

    my $where;
    if ($id_key eq 'user_id' || $id_key eq 'driver_unique_id') {
        $where = $id_key;
    }
    elsif ($id_key eq 'username' || $id_key eq 'email_address') {
        $id_key = 'driver_username' if $id_key eq 'username';
        $id_val = Socialtext::String::trim(lc $id_val);
        $where = "LOWER($id_key)";
    }
    else {
        warn "invalid user ID lookup key '$id_key'";
        return undef;
    }


    my ($where_clause, @bindings);

    if ($where eq 'user_id') {
        # if we don't check this for being an integer here, the SQL query will
        # die.  Since looking up by a non-numeric user_id would return no
        # results, mimic that behaviour instead of throwing the exception.
        return undef if $id_val =~ /\D/;

        $where_clause = qq{user_id = ?};
        @bindings = ($id_val);
    }
    else {
        die "no driver key?!" unless $driver_key;
        my $search_deleted = (ref($driver_key) eq 'ARRAY');
        if (!$search_deleted) {
            $where_clause = qq{driver_key = ? AND $where = ?};
            @bindings = ($driver_key, $id_val);
        }
        else {
            die "no user factories configured?!" unless @$driver_key;
            my $placeholders = '?,' x @$driver_key;
            chop $placeholders;
            $where_clause = qq{driver_key NOT IN ($placeholders) AND $where=?};
            @bindings = (@$driver_key, $id_val);
            $driver_key = 'Deleted'; # if we get any results, make it Deleted
        }
    }

    my $sth = sql_execute(
        qq{SELECT * FROM users WHERE $where_clause},
        @bindings
    );

    my $row = $sth->fetchrow_hashref();
    return undef unless $row;

    # Always set this; the query returns the same value *except* when we're
    # looking for Deleted users.
    $row->{driver_key} = $driver_key;

    $row->{username} = delete $row->{driver_username};
    return $class->NewHomunculus($row);
}

sub NewUserRecord {
    my $class = shift;
    my $proto_user = shift;

    $proto_user->{user_id} ||= $class->NewUserId();

    # always need a cached_at during INSERT, default it to 'now'
    $proto_user->{cached_at} = $class->Now()
        if (!$proto_user->{cached_at} or 
            !ref($proto_user->{cached_at}) &&
            $proto_user->{cached_at} eq 'now');

    die "cached_at must be a DateTime object"
        unless (ref($proto_user->{cached_at}) && 
                $proto_user->{cached_at}->isa('DateTime'));

    my %insert_args = map { $_ => $proto_user->{$_} } @all_fields;

    $insert_args{driver_username} = $proto_user->{driver_username};
    delete $insert_args{username};

    $insert_args{cached_at} = 
        sql_format_timestamptz($proto_user->{cached_at});

    sql_insert('users' => \%insert_args);
}

sub UpdateUserRecord {
    my $class = shift;
    my $proto_user = shift;

    die "must have a user_id to update a user record"
        unless $proto_user->{user_id};
    die "must supply a cached_at parameter (undef means 'leave db alone')"
        unless exists $proto_user->{cached_at};

    $proto_user->{cached_at} = $class->Now()
        if ($proto_user->{cached_at} && 
            !ref($proto_user->{cached_at}) &&
            $proto_user->{cached_at} eq 'now');

    my %update_args = map { $_ => $proto_user->{$_} } 
                      grep { exists $proto_user->{$_} }
                      @all_fields;

    if ($proto_user->{driver_username}) {
        $update_args{driver_username} = $proto_user->{driver_username};
    }
    delete $update_args{username};

    if (!$update_args{cached_at}) {
        # false/undef means "don't change cached_at in the db"
        delete $update_args{cached_at};
    }
    else {
        die "cached_at must be a DateTime object"
            unless (ref($proto_user->{cached_at}) && 
                    $proto_user->{cached_at}->isa('DateTime'));

        $update_args{cached_at} = 
            sql_format_timestamptz($update_args{cached_at});
    }

    sql_update('users' => \%update_args, 'user_id');

    Socialtext::User::Cache->Clear();
}

sub DeleteUserRecord {
    my $self = shift;
    my %p = @_;
    return unless $p{force};
    return unless $p{user_id};
    sql_execute('DELETE FROM users WHERE user_id = ?', $p{user_id});
}

sub ExpireUserRecord {
    my $self = shift;
    my %p = @_;
    return unless $p{user_id};
    sql_execute(q{
            UPDATE users 
            SET cached_at = '-infinity'
            WHERE user_id = ?
        }, $p{user_id});
}

1;

=head1 NAME

Socialtext::User::Factory - Abstract base class for User factories.

=head1 DESCRIPTION

C<Socialtext::User::Factory> provides class methods that factories should use when retrieving/storing users in the system database.

Subclasses of this module *MUST* be named C<Socialtext::User::${driver_name}::Factory>

A "Driver" is the code used to instantiate Homunculus objects.  A "Factory" is an instance of a driver (C<Socialtext::User::LDAP::Factory> can have multiple factories configured, while C<Socialtext::User::Default::Factory> can only have one instance).

=head1 METHODS

=over

=item B<driver_name()>

The driver_name is a name that identifies this factory class.  Code will use
this name to initialize a driver instance ("factory").

=item B<driver_id()>

Returns the unique ID for the instance of the data store ("factory") this user
was found in.  This unique ID is internal and likely has no meaning to a user.
e.g. "0deadbeef0".

=item B<driver_key()>

Returns the fully qualified driver key in the form ("name:id") of this factory (driver instance).

The database will use this key to map users to their owning factories.  This
key is internal and likely has no meaning to an end-user.  e.g.
"LDAP:0deadbeef0".

=item B<new_homunculus(\%proto_user)>

Calls C<NewHomunculus(\%proto_user)>, overriding the driver_key field of the proto_user with the result of C<$self->driver_key>.

=item B<get_homunculus($id_key => $id_val)>

Calls C<GetHomunculus()>, passing in the driver_key of this factory.

=back

=head2 CLASS METHODS

=over

=item B<NewHomunculus(\%proto_user)>

Helper method that will instantiate a Homunculus based on the driver_key field
contained in the C<\%proto_user> hashref.

Homunculi need to have a user_id, driver_key and driver_unique_id to be created.

=item B<NewUserId()>

Returns a new unique identifier for use in creating new users.

=item B<ResolveId(\%params)>

Uses "driver_key" and "driver_unique_id" in the params argument to obtain the user_id corresponding to those values.

=item B<Now()>

Creates a DateTime object with the current time from C<Time::HiRes::time> and
returns it.

=item B<GetHomunculus($id_key,$id_val,$driver_key)>

Retrieves a new user record from the system database and uses C<NewHomunculus()> to instantiate it.

Given an identifying key, it's value, and the driver key, dip into the
database and return a C<Socialtext::User::Base> homunculus.  For example, if
given a 'Default' driver key, the returned object will be a
C<Socialtext::User::Default> homunculus.

If C<$id_key> is 'user_id', the C<$driver_key> is ignored as a parameter.

=item B<NewUserRecord(\%proto_user)>

Creates a new user record in the system database.

Uses the specified hashref to obtain the necessary values.

The 'cached_at' field must be a valid C<DateTime> object.  If it is missing or
set to the string "now", the current time (with C<Time::HiRes> accuracy) is
used.

If a user_id is not supplied, a new one will be created with C<NewUserId()>.

=item B<UpdateUserRecord(\%proto_user)>

Updates an existing user record in the system database.  

A 'user_id' must be present in the C<\%proto_user> argument for this update to
work.

Uses the specified hashref to obtain the necessary values.  'user_id' cannot
be updated and will be silently ignored.

If the 'cached_at' parameter is undef, that field is left alone in the
database.  Otherwise, 'cached_at' must be a valid C<DateTime> object.  If it
is missing or set to the string "now", the current time (with C<Time::HiRes>
accuracy) is used.

Fields not specified by keys in the C<\%proto_user> will not be changed.  Any
keys who's value is undef will be set to NULL in the database.

=item B<DeleteUserRecord(user_id => 42)>

Obliterates a user record from the system.

B<DANGER:> In almost all cases, users should B<not> be deleted as there are
foreign keys for far too many other tables, and even if a user is no longer
active they are still likely needed when looking up page authors, history, or
other information.

Unless you pass C<< force => 1 >> this class method will do nothing.

=item B<ExpireUserRecord(user_id => 42)>

Expires the specified user.

The `cached_at` field of the specified user is set to '-infinity' in the
database.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
