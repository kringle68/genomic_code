DROP TABLE IF EXISTS pending_view_request;
DROP TABLE IF EXISTS map_view_lane_mapper; 
DROP TABLE IF EXISTS map_view_lane;
DROP TABLE IF EXISTS map_view_project_mapper;
DROP TABLE IF EXISTS db_projects; 
DROP TABLE IF EXISTS tracking_database;
DROP TABLE IF EXISTS schema_version; 
DROP TABLE IF EXISTS management_cumulative_stats;
DROP TABLE IF EXISTS management_running_stats;
DROP TABLE IF EXISTS management_import_date; 
DROP TABLE IF EXISTS management_all_sequences;
DROP TABLE IF EXISTS weekly_lane_report;
DROP TABLE IF EXISTS sample_id_mapping;
DROP TABLE IF EXISTS vrpipe_stepstate;
DROP TABLE IF EXISTS vrpipe_pipelinesetup;
DROP TABLE IF EXISTS vrpipe_file_info;
DROP TABLE IF EXISTS vrpipe_usage_top_level;
DROP TABLE IF EXISTS vrpipe_usage_total;
DROP TABLE IF EXISTS vrpipe_root_top_level;



CREATE TABLE tracking_database(
  db_id INT AUTO_INCREMENT NOT NULL,
  db_name VARCHAR(100) NOT NULL,
  imported datetime NOT NULL,
  PRIMARY KEY (db_id),
  UNIQUE (db_name)
);
ALTER TABLE tracking_database ADD INDEX tracking_db_id (db_id); 
ALTER TABLE tracking_database ADD INDEX tracking_db_name (db_name);

CREATE TABLE schema_version (
  schema_version mediumint(8) unsigned NOT NULL,
  imported datetime NOT NULL,
  PRIMARY KEY  (schema_version)
);

CREATE TABLE db_projects (
  id INT AUTO_INCREMENT NOT NULL,
  db_id INT NOT NULL,
  project_id smallint(5) unsigned NOT NULL,
  project_name varchar(255) NOT NULL,
  ssid mediumint(8) unsigned DEFAULT NULL,
  imported datetime NOT NULL,
  PRIMARY KEY (id),
  KEY db_id (db_id),
  KEY project_id (project_id),
  FOREIGN KEY(db_id) REFERENCES tracking_database(db_id) ON DELETE CASCADE
);

CREATE TABLE pending_view_request (
  id INT AUTO_INCREMENT NOT NULL,
  db_id INT NOT NULL,
  project_id smallint(5) unsigned NOT NULL,
  project_name varchar(255) NOT NULL,
  sample_name varchar(40) NOT NULL default '',
  request_type enum('library', 'sequence', 'multiplex', 'unknown') default 'unknown',
  seq_status enum('unknown','pendin  db_name VARCHAR(100) NOT NULL,g','started') default 'unknown',
  changed datetime NOT NULL,
  ssid mediumint(8) unsigned default NULL,
  imported datetime NOT NULL,
  PRIMARY KEY  (id),
  KEY db_id (db_id),
  KEY project_id (project_id),
  KEY project_name (project_name),
  KEY sample_name (sample_name),
  KEY ssid (ssid),
  FOREIGN KEY(db_id) REFERENCES tracking_database(db_id) ON DELETE CASCADE, 
  FOREIGN KEY(project_id) REFERENCES db_projects(project_id) ON DELETE CASCADE 
);

ALTER TABLE pending_view_request ADD INDEX pending_view_db_id_idx (db_id); 
ALTER TABLE pending_view_request ADD UNIQUE INDEX pending_view_all_idx (project_id, project_name, sample_name, seq_status, changed, ssid, request_type);

CREATE TABLE map_view_lane (
  id INT AUTO_INCREMENT NOT NULL,
  db_id INT NOT NULL,
  project_id smallint(5) unsigned NOT NULL,
  project_name varchar(255) NOT NULL,
  db_lane_id mediumint(8) unsigned NOT NULL,
  lane_name varchar(255) NOT NULL,
  library_name varchar(255) NOT NULL,
  is_improved enum('yes', 'no', 'unknown') default 'unknown',
  is_called enum('yes', 'no', 'unknown') default 'unknown',
  imported datetime NOT NULL,
  PRIMARY KEY  (id),
  KEY db_lane_id (db_lane_id),
  KEY lane_name (lane_name),
  KEY library_name (library_name),
  FOREIGN KEY(db_id) REFERENCES tracking_database(db_id) ON DELETE CASCADE, 
  FOREIGN KEY(project_id) REFERENCES db_projects(project_id) ON DELETE CASCADE 
);

ALTER TABLE map_view_lane ADD INDEX map_view_db_proj_id_idx (db_id, project_id); 
ALTER TABLE map_view_lane ADD UNIQUE INDEX map_view_lane_all_idx (project_id, project_name, db_lane_id, lane_name, library_name, is_improved, is_called);

CREATE TABLE map_view_lane_mapper (
  id INT AUTO_INCREMENT NOT NULL,
  db_id INT NOT NULL,
  db_lane_id mediumint(8) unsigned NOT NULL,
  mapper_name VARCHAR(100) NOT NULL,
  imported datetime NOT NULL,
  PRIMARY KEY (id),
  KEY db_id (db_id),
  KEY db_lane_id (db_lane_id),
  FOREIGN KEY(db_id) REFERENCES tracking_database(db_id) ON DELETE CASCADE,  
  FOREIGN KEY(db_lane_id) REFERENCES map_view_lane(db_lane_id) ON DELETE CASCADE
);

ALTER TABLE map_view_lane_mapper ADD INDEX map_view_lane_mapper_idx (db_id, db_lane_id);

CREATE TABLE map_view_project_mapper (
  id INT AUTO_INCREMENT NOT NULL,
  db_id INT NOT NULL,
  project_id smallint(5) unsigned NOT NULL,
  mapper_name VARCHAR(100) NOT NULL,
  imported datetime NOT NULL,
  PRIMARY KEY (id),
  KEY db_id (db_id),
  KEY project_id (project_id),
  KEY mapper_name (mapper_name),
  FOREIGN KEY(db_id) REFERENCES tracking_database(db_id) ON DELETE CASCADE, 
  FOREIGN KEY(project_id) REFERENCES db_projects(project_id) ON DELETE CASCADE
);  

ALTER TABLE map_view_project_mapper ADD INDEX map_view_project_mapper_idx (db_id, project_id);

insert into schema_version values (19, NOW());

CREATE TABLE management_cumulative_stats(
  id INT AUTO_INCREMENT NOT NULL,
  db_name VARCHAR(100) NOT NULL, 
  project_name varchar(255) NOT NULL, 
  status varchar(30) NOT NULL, 
  request_type varchar(100) NOT NULL, 
  total INT NOT NULL, 
  date INT NOT NULL,
  PRIMARY KEY (id)
);
ALTER TABLE management_cumulative_stats ADD INDEX management_cumulative_stats_db_idx (db_name);
ALTER TABLE management_cumulative_stats ADD INDEX management_cumulative_stats_proj_idx (project_name);

CREATE TABLE management_running_stats(
  id INT AUTO_INCREMENT NOT NULL,
  db_name VARCHAR(100) NOT NULL, 
  project_name varchar(255) NOT NULL, 
  status varchar(30) NOT NULL, 
  request_type varchar(100) NOT NULL, 
  total INT NOT NULL, 
  date INT NOT NULL,
  PRIMARY KEY (id)
);
ALTER TABLE management_running_stats ADD INDEX management_running_stats_db_idx (db_name);
ALTER TABLE management_running_stats ADD INDEX management_running_stats_proj_idx (project_name);

CREATE TABLE management_import_date(
  id INT NOT NULL,
  imported_UTC INTEGER UNSIGNED NOT NULL
);

insert into management_import_date (id, imported_UTC) VALUES (1,1);

CREATE TABLE management_all_sequences(
  raw_seq INT NOT NULL,
  rmdp INT NOT NULL,
  utc INT NOT NULL,
  PRIMARY KEY (utc) 
);
ALTER TABLE management_all_sequences ADD INDEX management_all_sequences_db_idx (utc);

CREATE TABLE weekly_lane_report(
  db_name VARCHAR(100) NOT NULL,
  project_name varchar(255) NOT NULL,
  total_lanes INT NOT NULL,
  updated datetime NOT NULL,
  UNIQUE (db_name,project_name)
);

CREATE TABLE sample_id_mapping(
  id INT AUTO_INCREMENT NOT NULL,
  db_id INT NOT NULL,
  db_name VARCHAR(100) NOT NULL,  
  project_id smallint(5) unsigned NOT NULL,
  project_name varchar(255) NOT NULL,
  supplier_name varchar(255) DEFAULT NULL,
  accession_number varchar(50) DEFAULT NULL,
  sanger_sample_name varchar(40) NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE current_samples (
  name VARCHAR(255) NOT NULL,
  internal_id INT NOT NULL,
  common_name VARCHAR(255) NOT NULL,
  is_current INT NOT NULL,
  supplier_name VARCHAR(255) NOT NULL default ''
);

CREATE TABLE vrpipe_pipelinesetup (
  ps_id int(9) NOT NULL,
  ps_name varchar(64) NOT NULL,
  ps_user varchar(64) NOT NULL,
  ps_type varchar(64) NOT NULL,
  pipeline int(9) NOT NULL,
  output_root text NOT NULL
);

CREATE TABLE vrpipe_file_info (
  ps_id int(9) NOT NULL,
  ps_name varchar(64) NOT NULL,
  ps_user varchar(64) NOT NULL,  
  ps_type varchar(64) NOT NULL,
  step_number smallint(4) NOT NULL,
  file_id int(9) NOT NULL,
  s bigint(20) DEFAULT NULL,
  type VARCHAR(4) DEFAULT NULL,
  path VARCHAR(255) NOT NULL,
  path_root VARCHAR(128) DEFAULT NULL,
  mtime datetime DEFAULT NULL
);

CREATE TABLE vrpipe_root_top_level (
  path_root VARCHAR(128) DEFAULT NULL,
  file_type VARCHAR(32) DEFAULT NULL,
  s bigint(40) DEFAULT NULL,
  s_gb bigint(30) DEFAULT NULL,
  file_count int(9) DEFAULT NULL,
  top_level_display tinyint(1) DEFAULT NULL
);

CREATE TABLE vrpipe_usage_top_level (
  ps_id int(9) NOT NULL,
  ps_name varchar(64) NOT NULL,
  ps_user varchar(64) NOT NULL,
  ps_type varchar(64) NOT NULL,
  path_root VARCHAR(128) DEFAULT NULL,
  file_type VARCHAR(4) DEFAULT NULL,
  s bigint(30) DEFAULT NULL,
  s_gb bigint(22) DEFAULT NULL,
  file_count int(9) DEFAULT NULL
);

CREATE TABLE vrpipe_usage_total (
  ps_id int(9) NOT NULL,
  ps_name varchar(64) NOT NULL,
  ps_user varchar(64) NOT NULL,
  ps_type varchar(64) NOT NULL,
  total_s bigint(30) DEFAULT NULL,
  total_s_gb bigint(22) DEFAULT NULL,
  file_count int(9) DEFAULT NULL
);

--OBSOLETE:
--CREATE TABLE vrpipe_stepstate (
--  ps_id int(9) NOT NULL,
--  stepmember int(9) NOT NULL,
--  file int(9) NOT NULL,
--  step_number smallint(4) NOT NULL
--);
