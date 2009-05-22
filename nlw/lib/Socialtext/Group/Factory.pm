package Socialtext::Group::Factory;
# @COPYRIGHT@

use Moose::Role;
use Socialtext::Date;
use Socialtext::Exceptions qw(data_validation_error);
use Socialtext::Group;
use Socialtext::Group::Homunculus;
use Socialtext::SQL qw(:time);
use Socialtext::SQL::Builder qw(:all);
use Socialtext::l10n qw(loc);

has 'driver_key' => (
    is => 'ro', isa => 'Str',
    required => 1,
);

has 'driver_name' => (
    is => 'ro', isa => 'Str',
    lazy_build => 1,
);

has 'driver_id' => (
    is => 'ro', isa => 'Maybe[Str]',
    lazy_build => 1,
);

# Methods we require Factories consuming this Role to implement:
requires 'Create';
requires 'can_update_store';

sub _build_driver_name {
    my $self = shift;
    my ($name, $id) = split /:/, $self->driver_key();
    return $name;
}

sub _build_driver_id {
    my $self = shift;
    my ($name, $id) = split /:/, $self->driver_key();
    return $id;
}

# Expires a Group record in the local DB store
sub ExpireGroupRecord {
    my ($self, %p) = @_;
    my $group_id = $p{group_id};
    return unless $group_id;
    sql_execute( q{
        UPDATE groups
           SET cached_at = '-infinity'
         WHERE group_id = ?
        }, $group_id );
}

# Current date/time, as DateTime object
sub Now {
    return Socialtext::Date->now(hires=>1);
}

# Creates a new Group Homunculus
sub NewGroupHomunculus {
    my ($self, $proto_group) = @_;

    # determine type of Group Homunculus to create, and make sure that we've
    # got the appropriate module loaded.
    my ($driver_name, $driver_id) = split /:/, $proto_group->{driver_key};
    my $driver_class = join '::', Socialtext::Group->base_package, $driver_name;
    eval "require $driver_class";
    die "Couldn't load ${driver_class}: $@" if $@;

    # instantiate the homunculus, and return it back to the caller
    my $homey = $driver_class->new($proto_group);
    return $homey;
}

# Returns the next available Group Id
sub NewGroupId {
    return sql_nextval('groups___group_id');
}

# Creates a new Group object in the local DB store
sub NewGroupRecord {
    my ($self, $proto_group) = @_;

    # make sure that the Group has a "group_id"
    $proto_group->{group_id} ||= $self->NewGroupId();

    # new Group records default to being cached _now_.
    $proto_group->{cached_at} ||= $self->Now();

    # map Group attributes to SQL INSERT args
    my %insert_args =
        map { $_ => $proto_group->{$_} }
        @Socialtext::Group::Homunculus::all_fields;

    foreach my $field (@Socialtext::Group::Homunculus::datetime_fields) {
        if ($insert_args{$field}) {
            $insert_args{$field} = sql_format_timestamptz($insert_args{$field});
        }
    }

    # INSERT the new record into the DB
    sql_insert('groups', \%insert_args);
}

# Validates a hash-ref of Group data, cleaning it up where appropriate.  If
# the data isn't valid, this method throws a
# Socialtext::Exception::Datavalidation exception.
sub ValidateAndCleanData {
    my ($self, $group, $p) = @_;
    my @errors;
    my @buffer;

    # are we "creating a new group", or "updating an existing group"
    my $is_create = defined $group ? 0 : 1;

    # get the metaclass for the Group object, using the default Group
    # Homunculus metaclass if no Group was provided
    my $meta = defined $group
             ? $group->meta
             : Socialtext::Group::Homunculus->meta;

    # figure out which attributes are required; they're marked as required but
    # *DON'T* include any attributes that we build lazily (our convention is
    # that lazily built attrs depend on the value of some other attr, so
    # they're not inherently required on their own; they're derived)
    my @required_fields =
        map { $_->name }
        grep { $_->is_required and !$_->is_lazy_build }
        $meta->get_all_attributes;

    # new Groups *have* to have a Group Id
    $self->_validate_assign_group_id($p) if ($is_create);

    # new Groups *have* to have a creation date/time
    $self->_validate_assign_creation_datetime($p) if ($is_create);

    # new Groups *have* to have a creating User; default to a system-created
    # Group unless we've been told otherwise.
    $self->_validate_assign_created_by($p) if ($is_create);

    # trim fields, removing leading/trailing whitespace
    $self->_validate_trim_values($p);

    # check for presence of required attributes
    foreach my $field (@required_fields) {
        # field is required if either (a) we're creating a new Group record,
        # or (b) we were given a value to update it with
        if ($is_create or exists $p->{$field}) {
            @buffer= $self->_validate_check_required_field($field, $p);
            push @errors, @buffer if (@buffer);
        }
    }

    ### IF DATA FAILED TO VALIDATE, THROW AN EXCEPTION!
    if (@errors) {
        data_validation_error errors => \@errors;
    }
}

sub _validate_assign_group_id {
    my ($self, $p) = @_;
    $p->{group_id} ||= $self->NewGroupId();
    return;
}

sub _validate_assign_creation_datetime {
    my ($self, $p) = @_;
    $p->{creation_datetime} ||= $self->Now();
    return;
}

sub _validate_trim_values {
    my ($self, $p) = @_;
    map { $p->{$_} = Socialtext::String::trim($p->{$_}) }
        grep { !ref($p->{$_}) }
        grep { defined $p->{$_} }
        @Socialtext::Group::Homunculus::all_fields;
    return;
}

sub _validate_check_required_field {
    my ($self, $field, $p) = @_;
    unless ((defined $p->{$field}) and (length($p->{$field}))) {
        return loc('[_1] is a required field.',
            ucfirst Socialtext::Data::humanize_column_name($field)
        );
    }
    return;
}

sub _validate_assign_created_by {
    my ($self, $p) = @_;
    # unless we were told who is creating this Group, presume that it's being
    # created by the System-User
    $p->{created_by_user_id} ||= Socialtext::User->SystemUser()->user_id();
    return;
}

1;

=head1 NAME

Socialtext::Group::Factory - Group Factory Role

=head1 SYNOPSIS

  use Socialtext::Group;

  # instantiating a Group Factory
  $factory = Socialtext::Group->Factory(driver_key => $driver_key);

=head1 DESCRIPTION

C<Socialtext::Group::Factory> provides an I<abstract> Group Factory Role,
which can be consumed by your own Group Factory implementation.

=head1 METHODS

=over

=item B<$factory-E<gt>driver_key()>

The unique driver key for the Group factory.

=item B<$factory-E<gt>driver_name()>

The driver name, which is calculated from the C<driver_key>.

The driver name indicates which Group Factory type is instantiated (e.g.
"Default", "LDAP", etc).

=item B<$factory-E<gt>driver_id()>

The driver id for the Group Factory, which is calculated from the
C<driver_key>.

The driver id indicates a specific instance of this type of Group Factory.

=item B<$factory-E<gt>Create(\%proto_group)>

Attempts to create a new Group object in the data store, using the information
provided in the given C<\%proto_group> hash-ref.

Factories consuming this Role B<MUST> implement this method, and are
responsible for ensuring that they are doing proper validation/cleaning of the
data prior to creating the Group.

If your Factory is read-only and is not updateable, simply implement a stub
method which throws an exception to indicate error.

=item B<$factory-E<gt>can_update_store()>

Returns true if the data store behind this Group Factory is updateable,
returning false if the data store is read-only.

Factories consuming this Role B<MUST> implement this method to indicate if
they're updateable or not.

=item B<$factory-E<gt>ExpireGroupRecord(group_id =E<gt> $group_id)>

Expires the Group in our local DB.  Next time the Group is instantiated, the
Factory managing for the Group will refresh the Group information from its
data store.

=item B<$factory-E<gt>Now()>

Returns the current date/time in hi-res, as a C<DateTime> object.

=item B<$factory-E<gt>NewGroupHomunculus(\%proto_group)>

Creates a new Group Homunculus object based on the information provided in the
C<\%proto_group> hash-ref.

The C<\%proto_group> B<must> contain all of the attributes required for the
Group Homunculus to be instantiated, for that specific Homunculus type.

=item B<$factory-E<gt>NewGroupId()>

Returns a new unique Group Id.  Id returned is B<guaranteed> to be unique.

=item B<$factory-E<gt>NewGroupRecord(\%proto_group)>

Creates a new Group record in the local DB store, based on the information
provided in the C<\%proto_group> hash-ref.

A unique C<group_id> will be calculated for the Group if one is not available
in the C<\%proto_group>.

Groups default to being C<cached_at> "now", unless specified otherwise in the
C<\%proto_group>.

=item B<$factory-E<gt>ValidateAndCleanData($group, \%proto_group)>

Validates the data provided in the C<\%proto_group> hash-ref, with respect to
any existing C<$group> that we may (or may not) be updating.

If a C<$group> is provided, validation is performed as "we are updating that
Group with the data provided in the C<\%proto_group>".

If no C<$group> is provided, validation is performed as "we are validating
data for the purpose of creating a new Group".

In the event of error, this method throws a
C<Socialtext::Exception::DataValidation> error.

Validation/cleanup performed:

=over

=item *

New Groups must have a C<group_id>, and a unique Group Id is calculated
automatically if it is not provided.

Only applicable if you are I<creating> a new Group; if you are updating a
Group it is presumed that you already have a unique Group Id for the Group.

=item *

New Groups must have a <creation_datetime>, which defaults to "now" unless
provided.

Only applicable if you are I<creating> a new Group.

=item *

New Groups must have a <created_by_user_id>, which defaults to "the System
User" unless provided.

Only applicable if you are I<creating> a new Group.

=item *

All attributes are trimmed of leading/trailing whitespace.

=item *

Check for presence of all required attributes, as defined by the Group
Homunculus.

When creating a new Group, validation is performed against the baseline set of
attributes as defined in C<Socialtext::Group::Homunculus>.

When updating an existing Group, validation is performed against the
attributes defined by the provided Group Homunculus object.

=back

=back

=head1 IMPLEMENTING A GROUP FACTORY

In order to consume this Group Factory Role and implement a concrete Group
Factory, you need to provide implementations for the following methods:

=over

=item Create(\%proto_group)

=item can_update_store()

=back

Please refer to the L</METHODS> section above for more information on how
these methods are intended to behave.

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut