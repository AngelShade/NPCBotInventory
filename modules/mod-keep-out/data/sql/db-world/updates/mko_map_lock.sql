CREATE TABLE IF NOT EXISTS `mod_mko_map_lock` (
  `mapId` smallint(6) UNSIGNED DEFAULT NULL,
  `zoneID` smallint(6) UNSIGNED DEFAULT NULL,
  `comment` varchar(255) DEFAULT '',
  CONSTRAINT `MKO_Map` UNIQUE (`mapId`, `zoneID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


CREATE TABLE IF NOT EXISTS `mod_mko_whitelist` (
  `accountId` INT UNSIGNED NOT NULL,
  `added_by` VARCHAR(255) NOT NULL,   -- The GM or admin who added the player to the whitelist
  `timestamp` INT UNSIGNED NOT NULL,  -- Timestamp of when the account was whitelisted
  PRIMARY KEY (`accountId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
