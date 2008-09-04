BEGIN;

-- Remove the person fields that contain URIs to photos, now that
-- the photos are stored in DB

ALTER TABLE person
    DROP COLUMN photo;
ALTER TABLE person
    DROP COLUMN small_photo;

-- Add a primary_account_id column to UserMetadata which is permitted
-- to be NULL now, but will be NOT NULL in the future.

ALTER TABLE "UserMetadata"
    ADD COLUMN
        primary_account_id bigint;

ALTER TABLE "UserMetadata"
    ADD CONSTRAINT usermeta_account_fk
        FOREIGN KEY (primary_account_id)
        REFERENCES "Account"(account_id) ON DELETE CASCADE;

-- Create a view to represent the user to account relationship.
-- This should make it possible to change this relationship in the future
-- without any significant querying code changes
CREATE VIEW user_account AS
SELECT DISTINCT u.system_unique_id AS system_unique_id,
                u.driver_key AS driver_key,
                u.driver_unique_id AS driver_unique_id,
                u.driver_username AS driver_username,
                um.created_by_user_id AS creator_id,
                um.creation_datetime AS creation_datetime,
                um.primary_account_id AS primary_account_id,
                w.account_id AS secondary_account_id
    FROM "UserId" u 
         JOIN "UserMetadata" um ON (u.system_unique_id = um.user_id)
         LEFT JOIN "UserWorkspaceRole" uwr ON (um.user_id = uwr.user_id)
         LEFT JOIN "Workspace" w ON (uwr.workspace_id = w.workspace_id);

CREATE TABLE account_plugins (
    account_id bigint NOT NULL,
    plugin VARCHAR(128) NOT NULL
);

ALTER TABLE account_plugins
    ADD CONSTRAINT account_plugins_account_fk
        FOREIGN KEY (account_id)
        REFERENCES "Account"(account_id) ON DELETE CASCADE;

UPDATE "System"
   SET value = 10
 WHERE field = 'socialtext-schema-version';

COMMIT;
