#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More tests => 46;
use mocked 'Socialtext::SQL', qw/sql_ok/;
use mocked 'Socialtext::Page';
use mocked 'Socialtext::User';

BEGIN {
    use_ok 'Socialtext::Model::Pages';
}

my $COMMON_SELECT = <<EOSQL;
SELECT page.workspace_id, 
       "Workspace".name AS workspace_name, 
       page.page_id, 
       page.name, 
       page.last_editor_id AS last_editor_id, 
       editor.username AS last_editor_username, 
       page.last_edit_time AT TIME ZONE 'GMT' AS last_edit_time, 
       page.creator_id, 
       creator.username AS creator_username, 
       page.create_time AT TIME ZONE 'GMT' AS create_time, 
       page.current_revision_id, 
       page.current_revision_num, 
       page.revision_count, 
       page.page_type, 
       page.deleted, 
       page.summary 
    FROM page 
        JOIN "Workspace" USING (workspace_id) 
        JOIN "UserId" editor_id  ON (page.last_editor_id = editor_id.system_unique_id)
        JOIN "UserId" creator_id ON (page.creator_id     = creator_id.system_unique_id)
        LEFT JOIN "User" editor  ON (editor_id.driver_unique_id = editor.user_id)
        LEFT JOIN "User" creator ON (creator_id.driver_unique_id = creator.user_id)
EOSQL

By_seconds_limit: {
    Regular: {
        local @Socialtext::SQL::RETURN_VALUES = (
            {
                return => [{workspace_id => 9, page_id => 'page_id'}],
            },
        );
        Socialtext::Model::Pages->By_seconds_limit(
            seconds => 88,
            where => 'cows fly',
            count => 20,
            tag => 'foo',
            workspace_id => 9,
        );
        sql_ok(
            name => 'by_seconds_limit',
            sql => <<EOT,
$COMMON_SELECT
        JOIN page_tag USING (page_id, workspace_id) 
    WHERE page.deleted = ?::bool 
      AND page.workspace_id = ? 
      AND last_edit_time > 'now'::timestamptz - ?::interval 
      AND LOWER(page_tag.tag) = LOWER(?) ORDER BY page.last_edit_time DESC LIMIT ?
EOT
            args => [0,9,'88 seconds','foo', 20],
        );
        sql_ok(
            name => 'by_seconds_limit',
            sql => <<EOT,
SELECT workspace_id, page_id, tag 
    FROM page_tag 
    WHERE page_tag.workspace_id = ?
EOT
            args => [9],
        );
    }

    Workspace_id_list: {
        local @Socialtext::SQL::RETURN_VALUES = (
            {
                return => [{workspace_id => 9, page_id => 'page_id'}],
            },
        );
        Socialtext::Model::Pages->By_seconds_limit(
            since => '2008-01-01 01:01:01',
            where => 'cows fly',
            count => 20,
            tag => 'foo',
            workspace_ids => [1,2,3],
        );
        sql_ok(
            name => 'by_seconds_limit',
            sql => <<EOT,
$COMMON_SELECT
        JOIN page_tag USING (page_id, workspace_id) 
    WHERE page.deleted = ?::bool 
      AND page.workspace_id IN (?,?,?)
      AND last_edit_time > ?::timestamptz
      AND LOWER(page_tag.tag) = LOWER(?) ORDER BY page.last_edit_time DESC LIMIT ?
EOT
            args => [0,1,2,3,'2008-01-01 01:01:01','foo', 20],
        );
        sql_ok(
            name => 'by_seconds_limit',
            sql => <<EOT,
SELECT workspace_id, page_id, tag 
    FROM page_tag 
    WHERE page_tag.workspace_id IN (?,?,?)
EOT
            args => [1,2,3],
        );
    }

    Since: {
        local @Socialtext::SQL::RETURN_VALUES = (
            {
                return => [{workspace_id => 9, page_id => 'page_id'}],
            },
        );
        Socialtext::Model::Pages->By_seconds_limit(
            since => '2008-01-01',
            where => 'cows fly',
            count => 20,
            tag => 'foo',
            workspace_id => 9,
        );
        sql_ok(
            name => 'by_since_limit',
            sql => <<EOT,
$COMMON_SELECT
        JOIN page_tag USING (page_id, workspace_id) 
    WHERE page.deleted = ?::bool 
      AND page.workspace_id = ? 
      AND last_edit_time > ?::timestamptz
      AND LOWER(page_tag.tag) = LOWER(?) ORDER BY page.last_edit_time DESC LIMIT ?
EOT
            args => [0,9,'2008-01-01','foo', 20],
        );
        sql_ok(
            name => 'by_seconds_limit',
            sql => <<EOT,
SELECT workspace_id, page_id, tag 
    FROM page_tag 
    WHERE page_tag.workspace_id = ?
EOT
            args => [9],
        );
    }

    Neither_seconds_nor_since: {
        eval { 
            Socialtext::Model::Pages->By_seconds_limit(
                where => 'cows fly',
                count => 20,
                tag => 'foo',
                workspace_id => 9,
            );
        };
        ok $@;
    }

    Limit: {
        local @Socialtext::SQL::RETURN_VALUES = (
            {
                return => [{workspace_id => 9, page_id => 'page_id'}],
            },
        );
        Socialtext::Model::Pages->By_seconds_limit(
            seconds => 88,
            where => 'cows fly',
            limit => 20,
            tag => 'foo',
            workspace_id => 9,
        );
        sql_ok(
            name => 'by_seconds_limit',
            sql => <<EOT,
$COMMON_SELECT
        JOIN page_tag USING (page_id, workspace_id) 
    WHERE page.deleted = ?::bool 
      AND page.workspace_id = ? 
      AND last_edit_time > 'now'::timestamptz - ?::interval 
      AND LOWER(page_tag.tag) = LOWER(?) ORDER BY page.last_edit_time DESC LIMIT ?
EOT
            args => [0,9,'88 seconds','foo', 20],
        );
        sql_ok(
            name => 'by_seconds_limit',
            sql => <<EOT,
SELECT workspace_id, page_id, tag 
    FROM page_tag 
    WHERE page_tag.workspace_id = ?
EOT
            args => [9],
        );
    }

    Category: {
        ok 1;
        local @Socialtext::SQL::RETURN_VALUES = (
            {
                return => [{workspace_id => 9, page_id => 'page_id'}],
            },
        );
        Socialtext::Model::Pages->By_seconds_limit(
            seconds => 88,
            where => 'cows fly',
            count => 20,
            category => 'foo',
            workspace_id => 9,
        );
        sql_ok(
            name => 'by_seconds_limit',
            sql => <<EOT,
$COMMON_SELECT
        JOIN page_tag USING (page_id, workspace_id) 
    WHERE page.deleted = ?::bool 
      AND page.workspace_id = ? 
      AND last_edit_time > 'now'::timestamptz - ?::interval 
      AND LOWER(page_tag.tag) = LOWER(?) ORDER BY page.last_edit_time DESC LIMIT ?
EOT
            args => [0,9,'88 seconds','foo',20],
        );
        sql_ok(
            name => 'by_seconds_limit',
            sql => <<EOT,
SELECT workspace_id, page_id, tag 
    FROM page_tag 
    WHERE page_tag.workspace_id = ?
EOT
            args => [9],
        );
    }
}

All_active: {
    Regular: {
        local @Socialtext::SQL::RETURN_VALUES = (
            {
                return => [{workspace_id => 9, page_id => 'page_id'}],
            },
        );
        Socialtext::Model::Pages->All_active(
            hub => 'hub',
            count => 20,
            workspace_id => 9,
        );
        sql_ok(
            name => 'all_active',
            sql => <<EOT,
$COMMON_SELECT
    WHERE page.deleted = ?::bool 
      AND page.workspace_id = ? 
    LIMIT ?
EOT
            args => [0,9,20],
        );
        sql_ok(
            name => 'all_active',
            sql => <<EOT,
SELECT workspace_id, page_id, tag 
    FROM page_tag 
    WHERE page_tag.workspace_id = ?
EOT
            args => [9],
        );
    }
    No_workspace_filter: {
        local @Socialtext::SQL::RETURN_VALUES = (
            {
                return => [{workspace_id => 9, page_id => 'page_id'}],
            },
        );
        Socialtext::Model::Pages->All_active(
            hub => 'hub',
            count => 20,
        );
        sql_ok(
            name => 'all_active',
            sql => <<EOT,
$COMMON_SELECT
    WHERE page.deleted = ?::bool 
    LIMIT ?
EOT
            args => [0,20],
        );
        sql_ok(
            name => 'all_active',
            sql => <<EOT,
SELECT workspace_id, page_id, tag 
    FROM page_tag 
EOT
            args => [],
        );
    }
}

By_tag: {
    Regular: {
        local @Socialtext::SQL::RETURN_VALUES = (
            {
                return => [{workspace_id => 9, page_id => 'page_id'}],
            },
        );
        Socialtext::Model::Pages->By_tag(
            workspace_id => 9,
            limit => 33,
            tag => 'foo',
        );
        sql_ok(
            name => 'by_tag',
            sql => <<EOT,
$COMMON_SELECT
        JOIN page_tag USING (page_id, workspace_id) 
    WHERE page.deleted = ?::bool 
      AND page.workspace_id = ? 
      AND LOWER(page_tag.tag) = LOWER(?) ORDER BY page.last_edit_time DESC LIMIT ?
EOT
            args => [0,9,'foo',33],
        );
        sql_ok(
            name => 'by_tag',
            sql => <<EOT,
SELECT workspace_id, page_id, tag 
    FROM page_tag 
    WHERE page_tag.workspace_id = ?
EOT
            args => [9],
        );
    }
}

By_id: {
    single_page: {
        local @Socialtext::SQL::RETURN_VALUES = (
            {
                return => [{workspace_id => 9, page_id => 'monkey'}],
            },
        );
        Socialtext::Model::Pages->By_id(
            workspace_id => 9,
            page_id => 'monkey',
        );
        sql_ok(
            name => 'by_id',
            sql => <<EOT,
$COMMON_SELECT
    WHERE page.deleted = ?::bool 
      AND page.workspace_id = ? 
      AND page_id = ?
EOT
            args => [0,9,'monkey'],
        );
        sql_ok(
            name => 'by_id',
            sql => <<EOT,
SELECT workspace_id, page_id, tag 
    FROM page_tag 
    WHERE page_tag.workspace_id = ?
EOT
            args => [9],
        );
    }

    several_pages: {
        local @Socialtext::SQL::RETURN_VALUES = (
            {
                return => [{workspace_id => 9, page_id => 'monkey'}],
            },
        );
        Socialtext::Model::Pages->By_id(
            workspace_id => 9,
            page_id => ['monkey', 'ape', 'chimp'],
        );
        sql_ok(
            name => 'by_id',
            sql => <<EOT,
$COMMON_SELECT
    WHERE page.deleted = ?::bool 
      AND page.workspace_id = ? 
      AND page_id IN (?,?,?)
EOT
            args => [0,9,'monkey', 'ape', 'chimp'],
        );
        sql_ok(
            name => 'by_id',
            sql => <<EOT,
SELECT workspace_id, page_id, tag 
    FROM page_tag 
    WHERE page_tag.workspace_id = ?
EOT
            args => [9],
        );
    }

    several_pages_no_tags: {
        local @Socialtext::SQL::RETURN_VALUES = (
            {
                return => [{workspace_id => 9, page_id => 'monkey'}],
            },
        );
        Socialtext::Model::Pages->By_id(
            workspace_id     => 9,
            page_id          => [ 'monkey', 'ape', 'chimp' ],
            do_not_need_tags => 1,
        );
        sql_ok(
            name => 'by_id',
            sql => <<EOT,
$COMMON_SELECT
    WHERE page.deleted = ?::bool 
      AND page.workspace_id = ? 
      AND page_id IN (?,?,?)
EOT
            args => [0,9,'monkey', 'ape', 'chimp'],
        );
        is scalar(@Socialtext::SQL::SQL), 0, 'no other SQL calls were made';
    }
}
