-- Reference schema for w_clothing (applied automatically by server/core/migrations.lua)
-- Note: Character skin & equipped clothes are managed exclusively via w_lib (w.framework).

CREATE TABLE IF NOT EXISTS `w_creators_clothes` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `charid` VARCHAR(100) NOT NULL,
    `hash` BIGINT NOT NULL,
    `category` VARCHAR(64) NOT NULL,
    `palette` VARCHAR(64) NULL,
    `tint0` INT NULL,
    `tint1` INT NULL,
    `tint2` INT NULL,
    `source` VARCHAR(16) NULL,
    `acquired_at` TIMESTAMP NULL,
    `price_paid` DECIMAL(10,2) NULL,
    `currency` VARCHAR(8) NULL,
    PRIMARY KEY (`id`),
    INDEX `charid_idx` (`charid`),
    UNIQUE KEY `char_item` (`charid`, `hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `w_creators_colorways` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `charid` VARCHAR(100) NOT NULL,
    `hash` BIGINT NOT NULL,
    `palette` VARCHAR(64) NOT NULL,
    `tint0` INT NOT NULL,
    `tint1` INT NOT NULL,
    `tint2` INT NOT NULL,
    `price_paid` DECIMAL(10,2) NULL,
    `currency` VARCHAR(8) NULL,
    `acquired_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    INDEX `charid_idx` (`charid`),
    UNIQUE KEY `char_colorway` (`charid`, `hash`, `palette`, `tint0`, `tint1`, `tint2`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `w_creators_outfits` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `charid` VARCHAR(100) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    INDEX `charid_idx` (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `w_clothing_states` (
    `charid` VARCHAR(100) NOT NULL,
    `states` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `w_creators_locations` (
    `id` VARCHAR(64) NOT NULL,
    `type` VARCHAR(16) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `position` INT NOT NULL DEFAULT 0,
    `updated_by` VARCHAR(100) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
