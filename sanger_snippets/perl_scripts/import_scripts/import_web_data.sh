#!/bin/sh
umask 002

/software/bin/perl /nfs/users/nfs_j/jm23/work/web/current/import_scripts/import_db_projects_web
#/software/bin/perl /nfs/users/nfs_j/jm23/work/web/current/import_scripts/import_pending_view_web
#/software/bin/perl /nfs/users/nfs_j/jm23/work/web/current/import_scripts/import_map_view_web
/software/bin/perl /nfs/users/nfs_j/jm23/work/web/current/import_scripts/import_management_stats
/software/bin/perl /nfs/users/nfs_j/jm23/work/web/current/import_scripts/import_sequence_all_stats
/software/bin/perl /nfs/users/nfs_j/jm23/work/web/current/import_scripts/import_sample_id_mapping
