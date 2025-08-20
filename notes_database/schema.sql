-- Schema for users and notes tables for the Personal Notes Organizer application
-- This file is idempotent: it uses CREATE TABLE IF NOT EXISTS and guards to avoid duplicate creation

-- Ensure database exists (for direct usage); startup.sh will also create DB
CREATE DATABASE IF NOT EXISTS myapp;
USE myapp;

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Primary key for users',
  email         VARCHAR(255)    NOT NULL COMMENT 'Unique email address used for login',
  password_hash VARCHAR(255)    NOT NULL COMMENT 'Password hash (argon2/bcrypt)',
  display_name  VARCHAR(100)    NULL     COMMENT 'User display name',
  created_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation timestamp',
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Notes table
CREATE TABLE IF NOT EXISTS notes (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Primary key for notes',
  user_id     BIGINT UNSIGNED NOT NULL COMMENT 'Owner (FK to users.id)',
  title       VARCHAR(255)    NOT NULL COMMENT 'Note title',
  content     MEDIUMTEXT      NULL     COMMENT 'Note content in plain text or markdown',
  tags        JSON            NULL     COMMENT 'JSON array of tags (MySQL 8.0 JSON type)',
  is_archived TINYINT(1)      NOT NULL DEFAULT 0 COMMENT 'Archive flag',
  updated_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update time',
  created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation time',
  PRIMARY KEY (id),
  KEY idx_notes_user_id (user_id),
  KEY idx_notes_is_archived (is_archived),
  KEY idx_notes_updated_at (updated_at),
  -- Functional index for fast tag searching when tags is JSON array; uses generated column fallback if JSON index unsupported
  CONSTRAINT fk_notes_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Optional: helper generated column to enable indexing first tag (kept idempotent via guard)
-- This block checks and creates the column only if missing, then indexes it.
-- It is wrapped in a procedure to allow IF EXISTS checks.
DELIMITER $$

DROP PROCEDURE IF EXISTS ensure_notes_tag_idx $$
CREATE PROCEDURE ensure_notes_tag_idx()
BEGIN
  DECLARE col_count INT DEFAULT 0;
  DECLARE idx_count INT DEFAULT 0;

  -- Check if generated column first_tag exists
  SELECT COUNT(*) INTO col_count
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'notes'
    AND COLUMN_NAME = 'first_tag';

  IF col_count = 0 THEN
    -- Create virtual generated column extracting first tag (if tags is array)
    SET @alter_col := '
      ALTER TABLE notes
      ADD COLUMN first_tag VARCHAR(100)
        GENERATED ALWAYS AS (
          CASE
            WHEN JSON_VALID(tags) AND JSON_TYPE(tags) = ''ARRAY''
              THEN JSON_UNQUOTE(JSON_EXTRACT(tags, ''$[0]''))
            ELSE NULL
          END
        ) VIRTUAL
    ';
    PREPARE stmt FROM @alter_col;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;

  -- Create index on first_tag if it does not exist
  SELECT COUNT(*) INTO idx_count
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'notes'
    AND INDEX_NAME = 'idx_notes_first_tag';

  IF idx_count = 0 THEN
    SET @create_idx := 'CREATE INDEX idx_notes_first_tag ON notes (first_tag)';
    PREPARE stmt2 FROM @create_idx;
    EXECUTE stmt2;
    DEALLOCATE PREPARE stmt2;
  END IF;
END $$

CALL ensure_notes_tag_idx() $$
DROP PROCEDURE IF EXISTS ensure_notes_tag_idx $$

DELIMITER ;

-- Useful composite indexes for common queries
-- Idempotent creation with IF NOT EXISTS via dynamic checks (MySQL lacks IF NOT EXISTS for indexes before 8.0.13)
DELIMITER $$

DROP PROCEDURE IF EXISTS ensure_composite_indexes $$
CREATE PROCEDURE ensure_composite_indexes()
BEGIN
  DECLARE idx1 INT DEFAULT 0;
  DECLARE idx2 INT DEFAULT 0;

  SELECT COUNT(*) INTO idx1
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'notes'
    AND INDEX_NAME = 'idx_notes_user_archived_updated';

  IF idx1 = 0 THEN
    SET @sql1 := 'CREATE INDEX idx_notes_user_archived_updated ON notes (user_id, is_archived, updated_at DESC)';
    PREPARE s1 FROM @sql1;
    EXECUTE s1;
    DEALLOCATE PREPARE s1;
  END IF;

  SELECT COUNT(*) INTO idx2
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'notes'
    AND INDEX_NAME = 'idx_notes_user_created';

  IF idx2 = 0 THEN
    SET @sql2 := 'CREATE INDEX idx_notes_user_created ON notes (user_id, created_at DESC)';
    PREPARE s2 FROM @sql2;
    EXECUTE s2;
    DEALLOCATE PREPARE s2;
  END IF;
END $$
CALL ensure_composite_indexes() $$
DROP PROCEDURE IF EXISTS ensure_composite_indexes $$
DELIMITER ;
