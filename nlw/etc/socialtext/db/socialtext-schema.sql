
SET client_encoding = 'UTF8';
SET check_function_bodies = false;
SET client_min_messages = warning;


SET search_path = public, pg_catalog;

CREATE FUNCTION auto_vivify_user_rollups() RETURNS "trigger"
    AS $$
    BEGIN
        INSERT INTO rollup_user_signal (user_id) VALUES (NEW.user_id);
        RETURN NULL; -- trigger return val is ignored
    END
$$
    LANGUAGE plpgsql;

CREATE FUNCTION cleanup_sessions() RETURNS "trigger"
    AS $$
    BEGIN
        -- if this is too slow, randomize running the delete
        -- e.g. IF (RANDOM() * 5)::integer = 0 THEN ...
        DELETE FROM sessions
        WHERE last_updated < 'now'::timestamptz - '28 days'::interval;
        RETURN NULL; -- after trigger
    END
$$
    LANGUAGE plpgsql;

CREATE FUNCTION is_page_contribution("action" text) RETURNS boolean
    AS $$
BEGIN
    IF action IN ('edit_save', 'tag_add', 'tag_delete', 'comment', 'rename', 'duplicate', 'delete')
    THEN
        RETURN true;
    END IF;
    RETURN false;
END;
$$
    LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION is_profile_contribution("action" text) RETURNS boolean
    AS $$
BEGIN
    IF action IN ('edit_save', 'tag_add', 'tag_delete')
    THEN
        RETURN true;
    END IF;
    RETURN false;
END;
$$
    LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION signal_sent() RETURNS "trigger"
    AS $$
    BEGIN

        UPDATE rollup_user_signal
           SET sent_count = sent_count + 1,
               sent_latest = GREATEST(NEW."at", sent_latest),
               sent_earliest = LEAST(NEW."at", sent_earliest)
         WHERE user_id = NEW.user_id;

        NOTIFY new_signal; -- not strictly needed yet

        RETURN NULL; -- trigger return val is ignored
    END
$$
    LANGUAGE plpgsql;

CREATE AGGREGATE array_accum (
    BASETYPE = anyelement,
    SFUNC = array_append,
    STYPE = anyarray,
    INITCOND = '{}'
);

SET default_tablespace = '';

SET default_with_oids = false;

CREATE TABLE "Account" (
    account_id bigint NOT NULL,
    name varchar(250) NOT NULL,
    is_system_created boolean DEFAULT false NOT NULL,
    skin_name varchar(30) DEFAULT 's3'::varchar NOT NULL,
    email_addresses_are_hidden boolean,
    is_exportable boolean DEFAULT false NOT NULL,
    desktop_logo_uri varchar(250) DEFAULT '/static/desktop/images/sd-logo.png'::varchar,
    desktop_header_gradient_top varchar(7) DEFAULT '#4C739B'::varchar,
    desktop_header_gradient_bottom varchar(7) DEFAULT '#506481'::varchar,
    desktop_bg_color varchar(7) DEFAULT '#FFFFFF'::varchar,
    desktop_2nd_bg_color varchar(7) DEFAULT '#F2F2F2'::varchar,
    desktop_text_color varchar(7) DEFAULT '#000000'::varchar,
    desktop_link_color varchar(7) DEFAULT '#0081F8'::varchar,
    desktop_highlight_color varchar(7) DEFAULT '#FFFDD3'::varchar,
    allow_invitation boolean DEFAULT true NOT NULL
);

CREATE SEQUENCE "Account___account_id"
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE "Permission" (
    permission_id integer NOT NULL,
    name varchar(50) NOT NULL
);

CREATE SEQUENCE "Permission___permission_id"
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE "Role" (
    role_id integer NOT NULL,
    name varchar(20) NOT NULL,
    used_as_default boolean DEFAULT false NOT NULL
);

CREATE SEQUENCE "Role___role_id"
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE "System" (
    field varchar(1024) NOT NULL,
    value varchar(1024) NOT NULL,
    last_update timestamptz DEFAULT now()
);

CREATE TABLE "UserEmailConfirmation" (
    user_id bigint NOT NULL,
    sha1_hash varchar(27) NOT NULL,
    expiration_datetime timestamptz DEFAULT '-infinity'::timestamptz NOT NULL,
    is_password_change boolean DEFAULT false NOT NULL,
    workspace_id bigint
);

CREATE TABLE "UserMetadata" (
    user_id bigint NOT NULL,
    creation_datetime timestamptz DEFAULT now() NOT NULL,
    last_login_datetime timestamptz DEFAULT '-infinity'::timestamptz NOT NULL,
    email_address_at_import varchar(250),
    created_by_user_id bigint,
    is_business_admin boolean DEFAULT false NOT NULL,
    is_technical_admin boolean DEFAULT false NOT NULL,
    is_system_created boolean DEFAULT false NOT NULL,
    primary_account_id bigint
);

CREATE TABLE "UserWorkspaceRole" (
    user_id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    role_id integer NOT NULL,
    is_selected boolean DEFAULT true NOT NULL
);

CREATE TABLE "Watchlist" (
    workspace_id bigint NOT NULL,
    user_id bigint NOT NULL,
    page_text_id varchar(255) NOT NULL
);

CREATE TABLE "Workspace" (
    workspace_id bigint NOT NULL,
    name varchar(30) NOT NULL,
    title text NOT NULL,
    logo_uri text DEFAULT '' NOT NULL,
    homepage_weblog text DEFAULT '' NOT NULL,
    email_addresses_are_hidden boolean DEFAULT false NOT NULL,
    unmasked_email_domain varchar(250) DEFAULT ''::varchar NOT NULL,
    prefers_incoming_html_email boolean DEFAULT false NOT NULL,
    incoming_email_placement varchar(10) DEFAULT 'bottom'::varchar NOT NULL,
    allows_html_wafl boolean DEFAULT true NOT NULL,
    email_notify_is_enabled boolean DEFAULT true NOT NULL,
    sort_weblogs_by_create boolean DEFAULT false NOT NULL,
    external_links_open_new_window boolean DEFAULT true NOT NULL,
    basic_search_only boolean DEFAULT false NOT NULL,
    enable_unplugged boolean DEFAULT false NOT NULL,
    skin_name varchar(30) DEFAULT ''::varchar NOT NULL,
    custom_title_label varchar(100) DEFAULT ''::varchar NOT NULL,
    header_logo_link_uri varchar(100) DEFAULT 'http://www.socialtext.com/'::varchar NOT NULL,
    show_welcome_message_below_logo boolean DEFAULT false NOT NULL,
    show_title_below_logo boolean DEFAULT true NOT NULL,
    comment_form_note_top text DEFAULT '' NOT NULL,
    comment_form_note_bottom text DEFAULT '' NOT NULL,
    comment_form_window_height bigint DEFAULT 200 NOT NULL,
    page_title_prefix varchar(100) DEFAULT ''::varchar NOT NULL,
    email_notification_from_address varchar(100) DEFAULT 'noreply@socialtext.com'::varchar NOT NULL,
    email_weblog_dot_address boolean DEFAULT false NOT NULL,
    comment_by_email boolean DEFAULT false NOT NULL,
    homepage_is_dashboard boolean DEFAULT true NOT NULL,
    creation_datetime timestamptz DEFAULT now() NOT NULL,
    account_id bigint NOT NULL,
    created_by_user_id bigint NOT NULL,
    restrict_invitation_to_search boolean DEFAULT false NOT NULL,
    invitation_filter varchar(100),
    invitation_template varchar(30) DEFAULT 'st'::varchar NOT NULL,
    customjs_uri text DEFAULT '' NOT NULL,
    customjs_name text DEFAULT '' NOT NULL,
    no_max_image_size boolean DEFAULT false NOT NULL,
    cascade_css boolean DEFAULT true NOT NULL,
    uploaded_skin boolean DEFAULT false NOT NULL,
    allows_skin_upload boolean DEFAULT false NOT NULL,
    allows_page_locking boolean DEFAULT false NOT NULL
);

CREATE TABLE "WorkspaceBreadcrumb" (
    user_id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    "timestamp" timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE "WorkspaceCommentFormCustomField" (
    workspace_id bigint NOT NULL,
    field_name varchar(250) NOT NULL,
    field_order bigint NOT NULL
);

CREATE TABLE "WorkspacePingURI" (
    workspace_id bigint NOT NULL,
    uri varchar(250) NOT NULL
);

CREATE TABLE "WorkspaceRolePermission" (
    workspace_id bigint NOT NULL,
    role_id integer NOT NULL,
    permission_id integer NOT NULL
);

CREATE SEQUENCE "Workspace___workspace_id"
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE account_logo (
    account_id bigint NOT NULL,
    logo bytea NOT NULL
);

CREATE TABLE account_plugin (
    account_id bigint NOT NULL,
    plugin text NOT NULL
);

CREATE VIEW account_user AS
  SELECT "Workspace".account_id, "UserWorkspaceRole".user_id
   FROM "UserWorkspaceRole"
   JOIN "Workspace" USING (workspace_id)
UNION ALL 
 SELECT "UserMetadata".primary_account_id AS account_id, "UserMetadata".user_id
   FROM "UserMetadata";

CREATE TABLE container (
    container_id bigint NOT NULL,
    container_type text NOT NULL,
    user_id bigint,
    workspace_id bigint,
    account_id bigint,
    name text DEFAULT '' NOT NULL,
    page_id text,
    layout_template text,
    CONSTRAINT container_scope_ptr
            CHECK ((((((user_id IS NOT NULL) AND (account_id IS NULL)) AND (workspace_id IS NULL)) AND (page_id IS NULL)) OR ((((user_id IS NULL) AND (account_id IS NOT NULL)) AND (workspace_id IS NULL)) AND (page_id IS NULL))) OR (((user_id IS NULL) AND (account_id IS NULL)) AND (workspace_id IS NOT NULL)))
);

CREATE SEQUENCE container_id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE container_type (
    container_type text NOT NULL,
    path_args text[],
    links_template text,
    hello_template text,
    last_update timestamptz DEFAULT now() NOT NULL,
    "global" boolean DEFAULT false,
    columns integer DEFAULT 3,
    title text,
    purge_all_on_update boolean DEFAULT false
);

CREATE SEQUENCE default_gadget_id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE error (
    error_time integer NOT NULL,
    jobid bigint NOT NULL,
    message text NOT NULL,
    funcid integer DEFAULT 0 NOT NULL
);

CREATE TABLE event (
    "at" timestamptz NOT NULL,
    "action" text NOT NULL,
    actor_id integer NOT NULL,
    event_class text NOT NULL,
    context text,
    page_id text,
    page_workspace_id bigint,
    person_id integer,
    tag_name text,
    signal_id bigint
);

CREATE TABLE exitstatus (
    jobid bigint NOT NULL,
    funcid integer DEFAULT 0 NOT NULL,
    status smallint,
    completion_time integer,
    delete_after integer
);

CREATE TABLE funcmap (
    funcid serial NOT NULL,
    funcname varchar(255) NOT NULL
);

CREATE TABLE gadget (
    gadget_id bigint NOT NULL,
    src text,
    plugin text,
    href text,
    last_update timestamptz DEFAULT now() NOT NULL,
    content_type text,
    features text[],
    preloads text[],
    content text,
    title text,
    thumbnail text,
    scrolling boolean DEFAULT false,
    height integer,
    description text
);

CREATE SEQUENCE gadget_id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE gadget_instance (
    gadget_instance_id bigint NOT NULL,
    container_id bigint NOT NULL,
    gadget_id bigint NOT NULL,
    col integer NOT NULL,
    "row" integer NOT NULL,
    minimized boolean DEFAULT false,
    fixed boolean DEFAULT false,
    parent_instance_id bigint,
    "class" text
);

CREATE SEQUENCE gadget_instance_id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE gadget_instance_user_pref (
    gadget_instance_id bigint NOT NULL,
    user_pref_id bigint NOT NULL,
    value text
);

CREATE TABLE gadget_message (
    gadget_id bigint NOT NULL,
    lang text NOT NULL,
    country text DEFAULT '' NOT NULL,
    "key" text NOT NULL,
    value text NOT NULL
);

CREATE TABLE gadget_user_pref (
    user_pref_id bigint NOT NULL,
    gadget_id bigint NOT NULL,
    name text NOT NULL,
    datatype text,
    display_name text,
    default_value text,
    options text[],
    required boolean DEFAULT false
);

CREATE SEQUENCE gadget_user_pref_id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE gallery (
    gallery_id bigint NOT NULL,
    last_update timestamptz DEFAULT now() NOT NULL,
    account_id bigint,
    CONSTRAINT gallery_id_or_account_id
            CHECK (((gallery_id = 0) AND (account_id IS NULL)) OR ((gallery_id <> 0) AND (account_id IS NOT NULL)))
);

CREATE TABLE gallery_gadget (
    gadget_id bigint NOT NULL,
    gallery_id bigint NOT NULL,
    "position" integer NOT NULL,
    removed boolean DEFAULT false,
    socialtext boolean DEFAULT false,
    "global" boolean DEFAULT false
);

CREATE SEQUENCE gallery_id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE groups (
    group_id bigint NOT NULL,
    driver_key text NOT NULL,
    driver_unique_id text NOT NULL,
    driver_group_name text NOT NULL,
    account_id bigint NOT NULL,
    creation_datetime timestamptz DEFAULT now() NOT NULL,
    created_by_user_id bigint NOT NULL,
    cached_at timestamptz DEFAULT '-infinity'::timestamptz NOT NULL
);

CREATE SEQUENCE groups___group_id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE job (
    jobid serial NOT NULL,
    funcid integer NOT NULL,
    arg bytea,
    uniqkey varchar(255),
    insert_time integer,
    run_after integer NOT NULL,
    grabbed_until integer NOT NULL,
    priority smallint,
    "coalesce" varchar(255)
);

CREATE TABLE note (
    jobid bigint NOT NULL,
    notekey varchar(255) NOT NULL,
    value bytea
);

CREATE TABLE page (
    workspace_id bigint NOT NULL,
    page_id text NOT NULL,
    name text,
    last_editor_id bigint NOT NULL,
    last_edit_time timestamptz NOT NULL,
    creator_id bigint NOT NULL,
    create_time timestamptz NOT NULL,
    current_revision_id text NOT NULL,
    current_revision_num integer NOT NULL,
    revision_count integer NOT NULL,
    page_type text NOT NULL,
    deleted boolean NOT NULL,
    summary text,
    edit_summary text,
    locked boolean DEFAULT false NOT NULL
);

CREATE TABLE page_tag (
    workspace_id bigint NOT NULL,
    page_id text,
    tag text NOT NULL
);

CREATE TABLE person_tag (
    id integer NOT NULL,
    name text
);

CREATE TABLE person_watched_people__person (
    person_id1 integer NOT NULL,
    person_id2 integer NOT NULL
);

CREATE TABLE profile_attribute (
    user_id bigint NOT NULL,
    profile_field_id bigint NOT NULL,
    value text NOT NULL
);

CREATE TABLE profile_field (
    profile_field_id bigint NOT NULL,
    name text NOT NULL,
    field_class text NOT NULL,
    account_id bigint NOT NULL,
    title text NOT NULL,
    is_user_editable boolean DEFAULT true NOT NULL,
    is_hidden boolean DEFAULT false NOT NULL,
    CONSTRAINT profile_field_class_check
            CHECK (field_class IN ('attribute', 'contact', 'relationship'))
);

CREATE SEQUENCE profile_field___profile_field_id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE profile_photo (
    user_id integer NOT NULL,
    photo_image bytea,
    small_photo_image bytea
);

CREATE TABLE profile_relationship (
    user_id bigint NOT NULL,
    profile_field_id bigint NOT NULL,
    other_user_id bigint NOT NULL
);

CREATE TABLE rollup_user_signal (
    user_id bigint NOT NULL,
    sent_latest timestamptz DEFAULT '-infinity'::timestamptz NOT NULL,
    sent_earliest timestamptz DEFAULT 'infinity'::timestamptz NOT NULL,
    sent_count bigint DEFAULT 0 NOT NULL
);

CREATE TABLE search_set_workspaces (
    search_set_id bigint NOT NULL,
    workspace_id bigint NOT NULL
);

CREATE TABLE search_sets (
    search_set_id bigint NOT NULL,
    name varchar(40) NOT NULL,
    owner_user_id bigint NOT NULL
);

CREATE SEQUENCE search_sets___search_set_id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE sessions (
    id character(32) NOT NULL,
    a_session text NOT NULL,
    last_updated timestamptz NOT NULL
);

CREATE TABLE signal (
    signal_id bigint NOT NULL,
    "at" timestamptz DEFAULT now(),
    user_id bigint NOT NULL,
    body text NOT NULL,
    in_reply_to_id bigint,
    recipient_id bigint
);

CREATE TABLE signal_account (
    signal_id bigint NOT NULL,
    account_id bigint NOT NULL
);

CREATE SEQUENCE signal_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE "storage" (
    user_id bigint NOT NULL,
    "class" varchar(128),
    "key" varchar(128),
    value text,
    datatype varchar(10)
);

CREATE SEQUENCE tag_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE tag_people__person_tags (
    person_id integer NOT NULL,
    tag_id integer NOT NULL
);

CREATE TABLE topic_signal_page (
    signal_id integer NOT NULL,
    workspace_id integer NOT NULL,
    page_id text NOT NULL
);

CREATE TABLE topic_signal_user (
    signal_id bigint NOT NULL,
    user_id bigint NOT NULL
);

CREATE TABLE users (
    user_id bigint NOT NULL,
    driver_key text NOT NULL,
    driver_unique_id text NOT NULL,
    driver_username text NOT NULL,
    email_address text DEFAULT '' NOT NULL,
    "password" text DEFAULT '*none*' NOT NULL,
    first_name text DEFAULT '' NOT NULL,
    last_name text DEFAULT '' NOT NULL,
    cached_at timestamptz DEFAULT '-infinity'::timestamptz NOT NULL,
    last_profile_update timestamptz DEFAULT '-infinity'::timestamptz NOT NULL,
    is_profile_hidden boolean DEFAULT false NOT NULL
);

CREATE VIEW user_account AS
  SELECT DISTINCT u.user_id, u.driver_key, u.driver_unique_id, u.driver_username, um.created_by_user_id AS creator_id, um.creation_datetime, um.primary_account_id, w.account_id AS secondary_account_id, u.is_profile_hidden
   FROM users u
   JOIN "UserMetadata" um USING (user_id)
   LEFT JOIN "UserWorkspaceRole" uwr USING (user_id)
   LEFT JOIN "Workspace" w USING (workspace_id)
  ORDER BY u.user_id, u.driver_key, u.driver_unique_id, u.driver_username, um.created_by_user_id, um.creation_datetime, um.primary_account_id, w.account_id, u.is_profile_hidden;

CREATE TABLE user_group_role (
    user_id bigint NOT NULL,
    role_id integer NOT NULL,
    group_id bigint NOT NULL
);

CREATE TABLE user_plugin_pref (
    user_id bigint NOT NULL,
    plugin text NOT NULL,
    "key" text NOT NULL,
    value text NOT NULL
);

CREATE TABLE user_workspace_pref (
    user_id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    last_updated timestamptz DEFAULT now() NOT NULL,
    pref_blob text NOT NULL
);

CREATE SEQUENCE users___user_id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE webhook (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    "class" text NOT NULL,
    account_id bigint,
    workspace_id bigint,
    details_blob text DEFAULT '{}',
    url text NOT NULL
);

CREATE SEQUENCE webhook___webhook_id
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE TABLE workspace_plugin (
    workspace_id bigint NOT NULL,
    plugin text NOT NULL
);

CREATE TABLE workspace_plugin_pref (
    workspace_id bigint NOT NULL,
    plugin text NOT NULL,
    "key" text NOT NULL,
    value text NOT NULL
);

ALTER TABLE ONLY "Account"
    ADD CONSTRAINT "Account_pkey"
            PRIMARY KEY (account_id);

ALTER TABLE ONLY "Permission"
    ADD CONSTRAINT "Permission_pkey"
            PRIMARY KEY (permission_id);

ALTER TABLE ONLY "Role"
    ADD CONSTRAINT "Role_pkey"
            PRIMARY KEY (role_id);

ALTER TABLE ONLY "UserEmailConfirmation"
    ADD CONSTRAINT "UserEmailConfirmation_pkey"
            PRIMARY KEY (user_id);

ALTER TABLE ONLY "UserMetadata"
    ADD CONSTRAINT "UserMetadata_pkey"
            PRIMARY KEY (user_id);

ALTER TABLE ONLY "UserWorkspaceRole"
    ADD CONSTRAINT "UserWorkspaceRole_pkey"
            PRIMARY KEY (user_id, workspace_id);

ALTER TABLE ONLY "Watchlist"
    ADD CONSTRAINT "Watchlist_pkey"
            PRIMARY KEY (workspace_id, user_id, page_text_id);

ALTER TABLE ONLY "WorkspaceBreadcrumb"
    ADD CONSTRAINT "WorkspaceBreadcrumb_pkey"
            PRIMARY KEY (user_id, workspace_id);

ALTER TABLE ONLY "WorkspaceCommentFormCustomField"
    ADD CONSTRAINT "WorkspaceCommentFormCustomField_pkey"
            PRIMARY KEY (workspace_id, field_name);

ALTER TABLE ONLY "WorkspacePingURI"
    ADD CONSTRAINT "WorkspacePingURI_pkey"
            PRIMARY KEY (workspace_id, uri);

ALTER TABLE ONLY "WorkspaceRolePermission"
    ADD CONSTRAINT "WorkspaceRolePermission_pkey"
            PRIMARY KEY (workspace_id, role_id, permission_id);

ALTER TABLE ONLY "Workspace"
    ADD CONSTRAINT "Workspace_pkey"
            PRIMARY KEY (workspace_id);

ALTER TABLE ONLY account_logo
    ADD CONSTRAINT account_logo_pkey
            PRIMARY KEY (account_id);

ALTER TABLE ONLY account_plugin
    ADD CONSTRAINT account_plugin_pkey
            PRIMARY KEY (account_id, plugin);

ALTER TABLE ONLY account_plugin
    ADD CONSTRAINT account_plugin_ukey
            UNIQUE (plugin, account_id);

ALTER TABLE ONLY container
    ADD CONSTRAINT container_pk
            PRIMARY KEY (container_id);

ALTER TABLE ONLY container_type
    ADD CONSTRAINT container_type_pk
            PRIMARY KEY (container_type);

ALTER TABLE ONLY exitstatus
    ADD CONSTRAINT exitstatus_pkey
            PRIMARY KEY (jobid);

ALTER TABLE ONLY funcmap
    ADD CONSTRAINT funcmap_funcname_key
            UNIQUE (funcname);

ALTER TABLE ONLY funcmap
    ADD CONSTRAINT funcmap_pkey
            PRIMARY KEY (funcid);

ALTER TABLE ONLY gadget_instance
    ADD CONSTRAINT gadget_instace_pk
            PRIMARY KEY (gadget_instance_id);

ALTER TABLE ONLY gadget_instance_user_pref
    ADD CONSTRAINT gadget_instance_user_pref_pk
            PRIMARY KEY (gadget_instance_id, user_pref_id);

ALTER TABLE ONLY gadget_message
    ADD CONSTRAINT gadget_message_pk
            PRIMARY KEY (gadget_id, lang, country, "key");

ALTER TABLE ONLY gadget
    ADD CONSTRAINT gadget_pk
            PRIMARY KEY (gadget_id);

ALTER TABLE ONLY gadget
    ADD CONSTRAINT gadget_src
            UNIQUE (src);

ALTER TABLE ONLY gadget_user_pref
    ADD CONSTRAINT gadget_user_pref_pk
            PRIMARY KEY (user_pref_id);

ALTER TABLE ONLY gallery
    ADD CONSTRAINT gallery_account_uniq
            UNIQUE (account_id);

ALTER TABLE ONLY gallery
    ADD CONSTRAINT gallery_pk
            PRIMARY KEY (gallery_id);

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_group_id_pk
            PRIMARY KEY (group_id);

ALTER TABLE ONLY job
    ADD CONSTRAINT job_funcid_key
            UNIQUE (funcid, uniqkey);

ALTER TABLE ONLY job
    ADD CONSTRAINT job_pkey
            PRIMARY KEY (jobid);

ALTER TABLE ONLY note
    ADD CONSTRAINT note_pkey
            PRIMARY KEY (jobid, notekey);

ALTER TABLE ONLY page
    ADD CONSTRAINT page_pkey
            PRIMARY KEY (workspace_id, page_id);

ALTER TABLE ONLY person_tag
    ADD CONSTRAINT person_tag_pkey
            PRIMARY KEY (id);

ALTER TABLE ONLY person_watched_people__person
    ADD CONSTRAINT person_watched_people__person_pkey
            PRIMARY KEY (person_id1, person_id2);

ALTER TABLE ONLY profile_attribute
    ADD CONSTRAINT profile_attribute_pkey
            PRIMARY KEY (user_id, profile_field_id);

ALTER TABLE ONLY profile_field
    ADD CONSTRAINT profile_field_pkey
            PRIMARY KEY (profile_field_id);

ALTER TABLE ONLY profile_photo
    ADD CONSTRAINT profile_photo_pkey
            PRIMARY KEY (user_id);

ALTER TABLE ONLY profile_relationship
    ADD CONSTRAINT profile_relationship_pkey
            PRIMARY KEY (user_id, profile_field_id);

ALTER TABLE ONLY search_sets
    ADD CONSTRAINT search_sets_pkey
            PRIMARY KEY (search_set_id);

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_pkey
            PRIMARY KEY (id);

ALTER TABLE ONLY signal_account
    ADD CONSTRAINT signal_account_pkey
            PRIMARY KEY (signal_id, account_id);

ALTER TABLE ONLY signal
    ADD CONSTRAINT signal_pkey
            PRIMARY KEY (signal_id);

ALTER TABLE ONLY "System"
    ADD CONSTRAINT system_pkey
            PRIMARY KEY (field);

ALTER TABLE ONLY tag_people__person_tags
    ADD CONSTRAINT tag_people__person_tags_pkey
            PRIMARY KEY (person_id, tag_id);

ALTER TABLE ONLY topic_signal_page
    ADD CONSTRAINT topic_signal_page_pk
            PRIMARY KEY (signal_id, workspace_id, page_id);

ALTER TABLE ONLY topic_signal_user
    ADD CONSTRAINT topic_signal_user_pk
            PRIMARY KEY (signal_id, user_id);

ALTER TABLE ONLY user_group_role
    ADD CONSTRAINT user_group_role_pk
            PRIMARY KEY (user_id, group_id);

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey
            PRIMARY KEY (user_id);

ALTER TABLE ONLY workspace_plugin
    ADD CONSTRAINT workspace_plugin_pkey
            PRIMARY KEY (workspace_id, plugin);

ALTER TABLE ONLY workspace_plugin
    ADD CONSTRAINT workspace_plugin_ukey
            UNIQUE (plugin, workspace_id);

CREATE UNIQUE INDEX "Account___name"
	    ON "Account" (name);

CREATE UNIQUE INDEX "Permission___name"
	    ON "Permission" (name);

CREATE UNIQUE INDEX "Role___name"
	    ON "Role" (name);

CREATE UNIQUE INDEX "UserEmailConfirmation___sha1_hash"
	    ON "UserEmailConfirmation" (sha1_hash);

CREATE UNIQUE INDEX "UserMetadata___user_id"
	    ON "UserMetadata" (user_id);

CREATE INDEX "UserMetadata_primary_account_id"
	    ON "UserMetadata" (primary_account_id);

CREATE INDEX "UserWorkspaceRole_workspace_id"
	    ON "UserWorkspaceRole" (workspace_id);

CREATE UNIQUE INDEX "Workspace___lower___name"
	    ON "Workspace" (lower((name)::text));

CREATE INDEX "Workspace_account_id"
	    ON "Workspace" (account_id);

CREATE INDEX error_funcid_errortime
	    ON error (funcid, error_time);

CREATE INDEX error_jobid
	    ON error (jobid);

CREATE INDEX error_time
	    ON error (error_time);

CREATE INDEX exitstatus_deleteafter
	    ON exitstatus (delete_after);

CREATE INDEX exitstatus_funcid
	    ON exitstatus (funcid);

CREATE INDEX gallery_gadget_gadget_id_idx
	    ON gallery_gadget (gadget_id);

CREATE UNIQUE INDEX groups_driver_unique_id
	    ON groups (driver_key, driver_unique_id);

CREATE INDEX ix_container_account_id
	    ON container (account_id);

CREATE INDEX ix_container_container_type
	    ON container (container_type);

CREATE INDEX ix_container_user_id
	    ON container (user_id);

CREATE INDEX ix_container_user_id_type
	    ON container (container_type, user_id);

CREATE INDEX ix_container_workspace_id
	    ON container (workspace_id);

CREATE INDEX ix_event_actor_page_contribs
	    ON event (actor_id, page_workspace_id, page_id, "at")
	    WHERE ((event_class = 'page') AND is_page_contribution("action"));

CREATE INDEX ix_event_actor_time
	    ON event (actor_id, "at");

CREATE INDEX ix_event_at
	    ON event ("at");

CREATE INDEX ix_event_event_class_action_at
	    ON event (event_class, "action", "at");

CREATE INDEX ix_event_event_class_at
	    ON event (event_class, "at");

CREATE INDEX ix_event_for_page
	    ON event (page_workspace_id, page_id, "at")
	    WHERE (event_class = 'page');

CREATE INDEX ix_event_noview_at
	    ON event ("at")
	    WHERE ("action" <> 'view');

CREATE INDEX ix_event_noview_at_page
	    ON event ("at")
	    WHERE (("action" <> 'view') AND (event_class = 'page'));

CREATE INDEX ix_event_noview_at_person
	    ON event ("at")
	    WHERE (("action" <> 'view') AND (event_class = 'person'));

CREATE INDEX ix_event_noview_class_at
	    ON event (event_class, "at")
	    WHERE ("action" <> 'view');

CREATE INDEX ix_event_page_contention
	    ON event (page_workspace_id, page_id, "at")
	    WHERE ((event_class = 'page') AND (("action" = 'edit_start') OR ("action" = 'edit_cancel')));

CREATE INDEX ix_event_page_contribs
	    ON event ("at")
	    WHERE ((event_class = 'page') AND is_page_contribution("action"));

CREATE INDEX ix_event_person_contribs
	    ON event ("at")
	    WHERE ((event_class = 'person') AND is_profile_contribution("action"));

CREATE INDEX ix_event_person_contribs_actor
	    ON event (actor_id, "at")
	    WHERE ((event_class = 'person') AND is_profile_contribution("action"));

CREATE INDEX ix_event_person_contribs_person
	    ON event (person_id, "at")
	    WHERE ((event_class = 'person') AND is_profile_contribution("action"));

CREATE INDEX ix_event_person_time
	    ON event (person_id, "at")
	    WHERE (event_class = 'person');

CREATE INDEX ix_event_signal_actor_at
	    ON event (actor_id, "at")
	    WHERE (event_class = 'signal');

CREATE INDEX ix_event_signal_at
	    ON event ("at")
	    WHERE (event_class = 'signal');

CREATE INDEX ix_event_signal_id_at
	    ON event (signal_id, "at");

CREATE INDEX ix_event_workspace_page
	    ON event (page_workspace_id, page_id);

CREATE INDEX ix_gadget__src
	    ON gadget (src);

CREATE INDEX ix_gadget_instance__container_id
	    ON gadget_instance (container_id);

CREATE INDEX ix_gadget_instance__parent_id
	    ON gadget_instance (parent_instance_id);

CREATE INDEX ix_gadget_instance_user_pref__user_pref_id
	    ON gadget_instance_user_pref (user_pref_id);

CREATE INDEX ix_gadget_user_pref_gadget_id
	    ON gadget_user_pref (gadget_id);

CREATE INDEX ix_job_piro_non_null
	    ON job ((COALESCE((priority)::integer, 0)));

CREATE INDEX ix_page_events_contribs_actor_time
	    ON event (actor_id, "at")
	    WHERE ((event_class = 'page') AND is_page_contribution("action"));

CREATE INDEX ix_rollup_user_signal_user
	    ON rollup_user_signal (user_id);

CREATE INDEX ix_session_last_updated
	    ON sessions (last_updated);

CREATE INDEX ix_signal_account
	    ON signal_account (signal_id);

CREATE UNIQUE INDEX ix_signal_account_account
	    ON signal_account (account_id, signal_id);

CREATE INDEX ix_signal_at
	    ON signal ("at");

CREATE INDEX ix_signal_at_user
	    ON signal ("at", user_id);

CREATE INDEX ix_signal_recipient_at
	    ON signal (recipient_id, "at");

CREATE INDEX ix_signal_reply
	    ON signal (in_reply_to_id);

CREATE INDEX ix_signal_user_at
	    ON signal (user_id, "at");

CREATE INDEX ix_topic_signal_page_forward
	    ON topic_signal_page (workspace_id, page_id);

CREATE INDEX ix_topic_signal_page_reverse
	    ON topic_signal_page (signal_id);

CREATE INDEX ix_tsu_user
	    ON topic_signal_user (user_id);

CREATE INDEX job_coalesce
	    ON job ("coalesce" text_pattern_ops);

CREATE INDEX job_funcid_coalesce
	    ON job (funcid, "coalesce" text_pattern_ops);

CREATE INDEX job_funcid_runafter
	    ON job (funcid, run_after);

CREATE INDEX page_creator_time
	    ON page (creator_id, create_time);

CREATE INDEX page_tag__page_ix
	    ON page_tag (workspace_id, page_id);

CREATE INDEX page_tag__tag_ix
	    ON page_tag (tag);

CREATE INDEX page_tag__workspace_ix
	    ON page_tag (workspace_id);

CREATE INDEX page_tag__workspace_lower_tag_ix
	    ON page_tag (workspace_id, lower(tag));

CREATE INDEX page_tag__workspace_tag_ix
	    ON page_tag (workspace_id, tag);

CREATE UNIQUE INDEX person_tag__name
	    ON person_tag (name);

CREATE UNIQUE INDEX profile_field_name
	    ON profile_field (account_id, name);

CREATE INDEX profile_relationship_other_user_id
	    ON profile_relationship (other_user_id);

CREATE UNIQUE INDEX search_set_workspaces___search_set_id___search_set_id___workspa
	    ON search_set_workspaces (search_set_id, workspace_id);

CREATE UNIQUE INDEX search_sets___owner_user_id___owner_user_id___name
	    ON search_sets (owner_user_id, lower((name)::text));

CREATE INDEX storage_class_key_ix
	    ON "storage" ("class", "key");

CREATE INDEX storage_key_ix
	    ON "storage" ("key");

CREATE INDEX storage_key_value_type_ix
	    ON "storage" ("key", value)
	    WHERE (("key")::text = 'type');

CREATE INDEX storage_key_value_viewer_ix
	    ON "storage" ("key", value)
	    WHERE (("key")::text = 'viewer');

CREATE INDEX user_plugin_pref_idx
	    ON user_plugin_pref (user_id, plugin);

CREATE INDEX user_plugin_pref_key_idx
	    ON user_plugin_pref (user_id, plugin, "key");

CREATE INDEX user_workspace_pref_idx
	    ON user_workspace_pref (user_id, workspace_id);

CREATE UNIQUE INDEX users_driver_unique_id
	    ON users (driver_key, driver_unique_id);

CREATE INDEX users_lower_email
	    ON users (lower(email_address) text_pattern_ops);

CREATE UNIQUE INDEX users_lower_email_address_driver_key
	    ON users (lower(email_address), driver_key);

CREATE INDEX users_lower_first_name
	    ON users (lower(first_name) text_pattern_ops);

CREATE INDEX users_lower_last_name
	    ON users (lower(last_name) text_pattern_ops);

CREATE INDEX users_lower_username
	    ON users (lower(driver_username) text_pattern_ops);

CREATE UNIQUE INDEX users_lower_username_driver_key
	    ON users (lower(driver_username), driver_key);

CREATE INDEX watchlist_user_workspace
	    ON "Watchlist" (user_id, workspace_id);

CREATE INDEX webhook__class_account_ix
	    ON webhook ("class", account_id);

CREATE INDEX webhook__class_workspace_ix
	    ON webhook ("class", workspace_id);

CREATE INDEX webhook__workspace_class_ix
	    ON webhook ("class");

CREATE INDEX workspace_plugin_pref_idx
	    ON workspace_plugin_pref (workspace_id, plugin);

CREATE INDEX workspace_plugin_pref_key_idx
	    ON workspace_plugin_pref (workspace_id, plugin, "key");

CREATE TRIGGER sessions_insert
    AFTER INSERT ON sessions
    FOR EACH STATEMENT
    EXECUTE PROCEDURE cleanup_sessions();

CREATE TRIGGER signal_insert
    AFTER INSERT ON signal
    FOR EACH ROW
    EXECUTE PROCEDURE signal_sent();

CREATE TRIGGER users_insert
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE PROCEDURE auto_vivify_user_rollups();

ALTER TABLE ONLY account_logo
    ADD CONSTRAINT account_logo_account_fk
            FOREIGN KEY (account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY account_plugin
    ADD CONSTRAINT account_plugin_account_fk
            FOREIGN KEY (account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY container
    ADD CONSTRAINT container_account_id_fk
            FOREIGN KEY (account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY container
    ADD CONSTRAINT container_page_id_fk
            FOREIGN KEY (workspace_id, page_id)
            REFERENCES page(workspace_id, page_id) ON DELETE CASCADE;

ALTER TABLE ONLY container
    ADD CONSTRAINT container_type_fk
            FOREIGN KEY (container_type)
            REFERENCES container_type(container_type) ON DELETE CASCADE;

ALTER TABLE ONLY container
    ADD CONSTRAINT container_user_id_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY container
    ADD CONSTRAINT container_workspace_id_fk
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY event
    ADD CONSTRAINT event_actor_id_fk
            FOREIGN KEY (actor_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY event
    ADD CONSTRAINT event_page_fk
            FOREIGN KEY (page_workspace_id, page_id)
            REFERENCES page(workspace_id, page_id) ON DELETE CASCADE;

ALTER TABLE ONLY event
    ADD CONSTRAINT event_person_id_fk
            FOREIGN KEY (person_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY event
    ADD CONSTRAINT event_signal_id_fk
            FOREIGN KEY (signal_id)
            REFERENCES signal(signal_id) ON DELETE CASCADE;

ALTER TABLE ONLY "WorkspacePingURI"
    ADD CONSTRAINT fk_040b7e8582f72e5921dc071311fc4a5f
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY "WorkspaceRolePermission"
    ADD CONSTRAINT fk_1541e9b047972328826e1731bc85d4b8
            FOREIGN KEY (role_id)
            REFERENCES "Role"(role_id) ON DELETE CASCADE;

ALTER TABLE ONLY "UserWorkspaceRole"
    ADD CONSTRAINT fk_2d35adae0767c6ef9bd03ed923bd2380
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY "UserMetadata"
    ADD CONSTRAINT fk_51604686f50dc445f1d697a101a6a5cb
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY "WorkspaceBreadcrumb"
    ADD CONSTRAINT fk_537b27b50b95eea3e12ec792db0553f5
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY "WorkspaceBreadcrumb"
    ADD CONSTRAINT fk_55d1290a6baacca3b4fec189a739ab5b
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY "UserEmailConfirmation"
    ADD CONSTRAINT fk_777ad60e2bff785f8ff5ece0f3fc95c8
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY "WorkspaceRolePermission"
    ADD CONSTRAINT fk_82421c1ae80e2402c554a4bdec97ef4d
            FOREIGN KEY (permission_id)
            REFERENCES "Permission"(permission_id) ON DELETE CASCADE;

ALTER TABLE ONLY "Watchlist"
    ADD CONSTRAINT fk_82a2b3654e91cdeab69734a8a7e06fa0
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY "WorkspaceCommentFormCustomField"
    ADD CONSTRAINT fk_84d598c9d334a863af733a2647d59189
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY "UserWorkspaceRole"
    ADD CONSTRAINT fk_c00a18f1daca90d376037f946a0b3894
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY "WorkspaceRolePermission"
    ADD CONSTRAINT fk_d9034c52d2999d62d24bd2cfa30ac457
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY gadget_instance
    ADD CONSTRAINT gadget_instance_container_fk
            FOREIGN KEY (container_id)
            REFERENCES container(container_id) ON DELETE CASCADE;

ALTER TABLE ONLY gadget_instance
    ADD CONSTRAINT gadget_instance_gadget_fk
            FOREIGN KEY (gadget_id)
            REFERENCES gadget(gadget_id) ON DELETE CASCADE;

ALTER TABLE ONLY gadget_instance
    ADD CONSTRAINT gadget_instance_parent_fk
            FOREIGN KEY (parent_instance_id)
            REFERENCES gadget_instance(gadget_instance_id) ON DELETE RESTRICT;

ALTER TABLE ONLY gadget_instance_user_pref
    ADD CONSTRAINT gadget_instance_user_pref_gadget_instance_fk
            FOREIGN KEY (gadget_instance_id)
            REFERENCES gadget_instance(gadget_instance_id) ON DELETE CASCADE;

ALTER TABLE ONLY gadget_instance_user_pref
    ADD CONSTRAINT gadget_instance_user_pref_user_pref_fk
            FOREIGN KEY (user_pref_id)
            REFERENCES gadget_user_pref(user_pref_id) ON DELETE CASCADE;

ALTER TABLE ONLY gadget_message
    ADD CONSTRAINT gadget_message_gadget_fk
            FOREIGN KEY (gadget_id)
            REFERENCES gadget(gadget_id) ON DELETE CASCADE;

ALTER TABLE ONLY gadget_user_pref
    ADD CONSTRAINT gadget_user_pref_gadget_fk
            FOREIGN KEY (gadget_id)
            REFERENCES gadget(gadget_id) ON DELETE CASCADE;

ALTER TABLE ONLY gallery
    ADD CONSTRAINT gallery_account_fk
            FOREIGN KEY (account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY gallery_gadget
    ADD CONSTRAINT gallery_gadget_account_fk
            FOREIGN KEY (gallery_id)
            REFERENCES gallery(gallery_id) ON DELETE CASCADE;

ALTER TABLE ONLY gallery_gadget
    ADD CONSTRAINT gallery_gadget_fk
            FOREIGN KEY (gadget_id)
            REFERENCES gadget(gadget_id) ON DELETE CASCADE;

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_account_id_fk
            FOREIGN KEY (account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_created_by_user_id_fk
            FOREIGN KEY (created_by_user_id)
            REFERENCES users(user_id) ON DELETE RESTRICT;

ALTER TABLE ONLY signal
    ADD CONSTRAINT in_reply_to_fk
            FOREIGN KEY (in_reply_to_id)
            REFERENCES signal(signal_id) ON DELETE CASCADE;

ALTER TABLE ONLY page
    ADD CONSTRAINT page_creator_id_fk
            FOREIGN KEY (creator_id)
            REFERENCES users(user_id) ON DELETE RESTRICT;

ALTER TABLE ONLY page
    ADD CONSTRAINT page_last_editor_id_fk
            FOREIGN KEY (last_editor_id)
            REFERENCES users(user_id) ON DELETE RESTRICT;

ALTER TABLE ONLY page_tag
    ADD CONSTRAINT page_tag_workspace_id_page_id_fkey
            FOREIGN KEY (workspace_id, page_id)
            REFERENCES page(workspace_id, page_id) ON DELETE CASCADE;

ALTER TABLE ONLY page
    ADD CONSTRAINT page_workspace_id_fk
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY tag_people__person_tags
    ADD CONSTRAINT person_tags_fk
            FOREIGN KEY (person_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY person_watched_people__person
    ADD CONSTRAINT person_watched_people_fk
            FOREIGN KEY (person_id1)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY person_watched_people__person
    ADD CONSTRAINT person_watched_people_inverse_fk
            FOREIGN KEY (person_id2)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY profile_attribute
    ADD CONSTRAINT profile_attribute_field_fk
            FOREIGN KEY (profile_field_id)
            REFERENCES profile_field(profile_field_id) ON DELETE CASCADE;

ALTER TABLE ONLY profile_attribute
    ADD CONSTRAINT profile_attribute_user_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY profile_field
    ADD CONSTRAINT profile_field_account_fk
            FOREIGN KEY (account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY profile_photo
    ADD CONSTRAINT profile_photo_user_id_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY profile_relationship
    ADD CONSTRAINT profile_relationship_field_fk
            FOREIGN KEY (profile_field_id)
            REFERENCES profile_field(profile_field_id) ON DELETE CASCADE;

ALTER TABLE ONLY profile_relationship
    ADD CONSTRAINT profile_relationship_other_user_fk
            FOREIGN KEY (other_user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY profile_relationship
    ADD CONSTRAINT profile_relationship_user_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY rollup_user_signal
    ADD CONSTRAINT rollup_user_signal_user_id_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY signal_account
    ADD CONSTRAINT signal_account_fk
            FOREIGN KEY (signal_id)
            REFERENCES signal(signal_id) ON DELETE CASCADE;

ALTER TABLE ONLY signal_account
    ADD CONSTRAINT signal_account_signal_fk
            FOREIGN KEY (account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY signal
    ADD CONSTRAINT signal_recipient_fk
            FOREIGN KEY (recipient_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY signal
    ADD CONSTRAINT signal_user_id_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY tag_people__person_tags
    ADD CONSTRAINT tag_people_fk
            FOREIGN KEY (tag_id)
            REFERENCES person_tag(id) ON DELETE CASCADE;

ALTER TABLE ONLY topic_signal_page
    ADD CONSTRAINT topic_signal_page_forward
            FOREIGN KEY (workspace_id, page_id)
            REFERENCES page(workspace_id, page_id) ON DELETE CASCADE;

ALTER TABLE ONLY topic_signal_page
    ADD CONSTRAINT topic_signal_page_reverse
            FOREIGN KEY (signal_id)
            REFERENCES signal(signal_id) ON DELETE CASCADE;

ALTER TABLE ONLY topic_signal_user
    ADD CONSTRAINT tsu_signal_fk
            FOREIGN KEY (signal_id)
            REFERENCES signal(signal_id) ON DELETE CASCADE;

ALTER TABLE ONLY topic_signal_user
    ADD CONSTRAINT tsu_user_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY user_group_role
    ADD CONSTRAINT user_group_role_group_fk
            FOREIGN KEY (group_id)
            REFERENCES groups(group_id) ON DELETE CASCADE;

ALTER TABLE ONLY user_group_role
    ADD CONSTRAINT user_group_role_role_fk
            FOREIGN KEY (role_id)
            REFERENCES "Role"(role_id) ON DELETE CASCADE;

ALTER TABLE ONLY user_group_role
    ADD CONSTRAINT user_group_role_user_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY user_plugin_pref
    ADD CONSTRAINT user_plugin_pref_user_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY user_workspace_pref
    ADD CONSTRAINT user_workspace_pref_user_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY user_workspace_pref
    ADD CONSTRAINT user_workspace_pref_workspace_fk
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY "UserEmailConfirmation"
    ADD CONSTRAINT useremailconfirmation_workpace_id_fk
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY "UserMetadata"
    ADD CONSTRAINT usermeta_account_fk
            FOREIGN KEY (primary_account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY "UserWorkspaceRole"
    ADD CONSTRAINT userworkspacerole___role___role_id___role_id___n___1___1___0
            FOREIGN KEY (role_id)
            REFERENCES "Role"(role_id) ON DELETE CASCADE;

ALTER TABLE ONLY "Watchlist"
    ADD CONSTRAINT watchlist_user_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY webhook
    ADD CONSTRAINT webhook_account_id_fk
            FOREIGN KEY (account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY webhook
    ADD CONSTRAINT webhook_user_id_fk
            FOREIGN KEY (creator_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY webhook
    ADD CONSTRAINT webhook_workspace_id_fk
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY "Workspace"
    ADD CONSTRAINT workspace___account___account_id___account_id___n___1___1___0
            FOREIGN KEY (account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY "Workspace"
    ADD CONSTRAINT workspace_created_by_user_id_fk
            FOREIGN KEY (created_by_user_id)
            REFERENCES users(user_id) ON DELETE RESTRICT;

ALTER TABLE ONLY workspace_plugin_pref
    ADD CONSTRAINT workspace_plugin_pref_fk
            FOREIGN KEY (workspace_id, plugin)
            REFERENCES workspace_plugin(workspace_id, plugin) ON DELETE CASCADE;

ALTER TABLE ONLY workspace_plugin
    ADD CONSTRAINT workspace_plugin_workspace_fk
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

DELETE FROM "System" WHERE field = 'socialtext-schema-version';
INSERT INTO "System" VALUES ('socialtext-schema-version', '67');
