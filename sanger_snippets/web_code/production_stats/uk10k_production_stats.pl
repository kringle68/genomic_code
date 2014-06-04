#!/usr/local/bin/perl -T

BEGIN {
      $ENV{VRTRACK_HOST} = 'mcs10';
      $ENV{VRTRACK_PORT} = 3306;
      $ENV{VRTRACK_RO_USER} = 'vreseq_ro';
      $ENV{VRTRACK_RW_USER} = 'vreseq_rw';
      $ENV{VRTRACK_PASSWORD} = 't3aml3ss';
};

use strict;
use warnings;
use URI;

use lib '.';
use SangerPaths qw(core team145);
#use SangerPaths qw(core);
#use lib './modules';
use VertRes::Utils::VRTrackFactory;
use Data::Dumper;
use DBI;

use SangerWeb;

$ENV{PATH}= '/usr/local/bin';   # solely to stop taint from barfing

$|++;

#different modes/views possible
my $ERROR_DISPLAY = 0;
my $PROJ_VIEW = 1;
my $DB_VIEW = 2;

###############################CSS Stuff#############################

my $css = <<CSS ;

.centerFieldset {
text-align:center;
}

.centerFieldset fieldset {
margin-left:auto;
margin-right:auto;
/* INHERITED ALIGNMENT IS CENTER. ONLY INCLUDE THIS IF YOU WANT */
/* TO CHANGE THE ALIGNMENT OF THE CONTENTS OF THE FIELDSET */
text-align:left;
}

.centerFieldset table {
    margin-left:auto;
    margin-right:auto;
}

table.summary {
    border-collapse: collapse;
    font: 0.9em Verdana, Arial, Helvetica, sans-serif;
}

table.summary td {
    white-space: nowrap;
    text-align: right;
    padding-right: 1em;
    padding-left: 1em;
    padding-top: 2px;
    padding-bottom: 2px;
    border-bottom: #83a4c3 dotted 1px;
}

table.summary tr.header th, table.summary tr.header td {
    font-weight:bold;
    border-bottom: #83a4c3 solid 1px;
    text-align: left;
    vertical-align:middle;
}

table.summary tr.level th, table.summary tr.level td {
    font-weight:bold;
    border-bottom: #83a4c3 dotted 1px;
    text-align: left;
    vertical-align:middle;
}

table.summary tr.total th, table.summary tr.total td {
    font-weight:bold;
    background-color: #CBDCED;
    border-bottom: #83a4c3 dotted 1px;
    text-align: right;
    vertical-align:middle;
}

tr:nth-child(2n+1) {
	background-color: #ecf1ef;
}

/* Sortable tables */
table.sortable thead {
    background-color:#eee;
    color:#666666;
    font-weight: bold;
    cursor: default;
}


input.btn {
  font: bold 150% 'trebuchet ms',helvetica,sans-serif;
  border:1px solid;
  border-color: #707070 #000 #000 #707070;
}

input.btnhov { 
  cursor:pointer;
  border-color: #c63 #930 #930 #c63; 
}

.clear
{
    clear: both;
    display: block;
    overflow: hidden;
    visibility: hidden;
    width: 0;
    height: 0;
}

img.preview:hover {
    width: 480px;
    height: 480px;
}

.thumbnail{
position: relative;
z-index: 0;
}

.thumbnail:hover{
background-color: transparent;
z-index: 50;
}

.thumbnail span{ /*CSS for enlarged image*/
position: absolute;
padding: 5px;
left: -1000px;
visibility: hidden;
text-decoration: none;
}

.thumbnail span img{ /*CSS for enlarged image*/
border-width: 0;
padding: 2px;
}

.thumbnail:hover span{ /*CSS for enlarged image on hover*/
visibility: visible;
top: 0;
left: -480px; /*position where enlarged image should offset horizontally */

}

CSS

my $sw  = SangerWeb->new({
    'title'   => q(UK10K Production Statistics v0.1),
    'banner'  => q(),
    'inifile' => SangerWeb->document_root() . q(/Info/header.ini),
    #'stylesheet' => '/Teams/Team145/view.css'
    'jsfile'  => 'http://js.sanger.ac.uk/sorttable_v2.js',
    'style'   => $css,
});

#script name for self links
my $cgi = $sw->cgi();
my $SCRIPT_NAME = $cgi->url(-relative=>1);
my $web_db = 'vrtrack_web_index';

#decide on the entry point
my $mode = $cgi->param('mode');

if( defined( $mode ) && $mode == $ERROR_DISPLAY ) 
{
    my $message = $cgi->param('error_msg');
    
    print $sw->header();
    displayError( $message );
    print $sw->footer();
    
    exit;
}

my $vrtrack = VertRes::Utils::VRTrackFactory->instantiate(database => $web_db, mode => 'r');
redirectErrorScreen( $cgi, "Failed to connect to database: $web_db" ) unless defined( $vrtrack );

# List available databases.
if( !defined( $cgi->param('db')) ) {
    print $sw->header();
    displayDatabasesPage();
    print $sw->footer();
    exit;
}

# All other entry points require a database
my $db = $cgi->param('db');
if( ! defined $db ) {
    redirectErrorScreen( $cgi, "Database must be defined!" );
    exit;
}

# if( ! isDatabase( $db, $vrtrack ) ) {
#     redirectErrorScreen( $cgi, "Invalid database name!" );
#     exit;
# }

if( $mode == $DB_VIEW )
{
    print $sw->header();
    displayDatabasePage( $cgi, $db ); 
    print $sw->footer();
    exit;
}

# elsif( $mode == $PROJ_VIEW ) 
# {
#     my $pid = $cgi->param('proj_id');
#     if( ! defined( $pid ) )
#     {
#         redirectErrorScreen( $cgi, "Must provide a project ID" );
#         exit;
#     }
#     
#     print $sw->header();
#     displayProjectLanesPage($cgi, $vrtrack, $db, $pid);
#     print $sw->footer();
#     exit;
# }

else
{
    redirectErrorScreen( $cgi, "Invalid mode!" );
}

sub displayDatabasesPage 
{
    print qq[
        <h2 align="center" style="font: normal 900 1.5em arial">UK10K Production Statistics</h2>
        <div class="centerFieldset">
        <fieldset style="width: 700px">
        <legend>Global Statistics View</legend>
    	<table width="100%">
    	<tr>
    	<th style="color:blue;text-align:center;nowrap;width:90px">Database</th>
    	<th style="color:blue;text-align:center;nowrap">Total no. of samples with sequence</th>
    	<th style="color:blue;text-align:center;nowrap">Total raw bases (Gbp)</th>
    	<th style="color:blue;text-align:center;nowrap">Total rmdup mapped (Gbp)</th>
    	<th style="color:blue;text-align:center;nowrap">Total mapped target (Gbp)</th>
    	<th style="color:blue;text-align:center;nowrap">Mean target/sample coverage (Gbp)</th>
    	</tr>
    ];

    my @dbs = qw (cohort rare neuro obesity);
    foreach my $db ( @dbs )
    {
        my $global_stats;
        my $ucdb = ucfirst($db);
        my %seq_cen = ('1' => 'SC', '2' => 'BGI');
        if ($db eq 'cohort') {
        	foreach my $cen (1,2){
         		$global_stats = getGlobalStats($db, $cen);
         		print qq[<tr>];
         		print qq[<td style="text-align:left;nowrap"><a href="$SCRIPT_NAME?mode=$DB_VIEW&amp;db=vrtrack_uk10k_$db">$ucdb</a> ($seq_cen{$cen})</td>];
         		if ($cen == 1) {
         			print qq[<td align="right"><a href="http://intwebdev.sanger.ac.uk/Teams/Team145/dev/sample-charts-json.htm?db=vrtrack_uk10k_$db&amp;project=All">$$global_stats[0]</a></td>];
         		}
         		else {
         			print qq[<td align="right">$$global_stats[0]</td>];
         		}
         		print qq[<td align="right"><a href="http://intwebdev.sanger.ac.uk/Teams/Team145/dev/sequence-charts-json.htm?db=vrtrack_uk10k_$db&amp;project=All">$$global_stats[1]</a></td><td align="right"><a href="http://intwebdev.sanger.ac.uk/Teams/Team145/dev/sequence-charts-json.htm?db=vrtrack_uk10k_$db&amp;project=All">$$global_stats[2]</a></td><td align="right">-</td><td align="center">$$global_stats[3]</td>];
         	}
         }
        else {
        	$global_stats = getGlobalStatsExome($db);
        	print qq[<tr>];
        	print qq[<td style="text-align:left;nowrap"><a href="$SCRIPT_NAME?mode=$DB_VIEW&amp;db=vrtrack_uk10k_$db">$ucdb</a></td><td align="right"><a href="http://intwebdev.sanger.ac.uk/Teams/Team145/dev/sample-charts-json.htm?db=vrtrack_uk10k_$db&amp;project=All">$$global_stats[0]</a></td><td align="right"><a href="http://intwebdev.sanger.ac.uk/Teams/Team145/dev/sequence-charts-json.htm?db=vrtrack_uk10k_$db&amp;project=All">$$global_stats[1]</a></td><td align="right"><a href="http://intwebdev.sanger.ac.uk/Teams/Team145/dev/sequence-charts-json.htm?db=vrtrack_uk10k_$db&amp;project=All">$$global_stats[2]</a></td><td align="right">$$global_stats[3]</td><td align="center">$$global_stats[4]</td>];
       }
        print qq[</tr>];
    }
    print qq[<tr>];
    print qq[<td style="text-align:left;nowrap"><a href="http://intwebdev.sanger.ac.uk/Teams/Team145/dev/sequence-totals-json.htm">All projects</a></td><td "colspan="5"></td></tr>];
    print qq[
    	</table>
       	</fieldset>
       	</div>
    ];
}

sub displayDatabasePage
{
    my $cgi = shift;
    my $db = shift;
    my $ucdb = uc($db);
    my @projects = @{fetchProjects($db)};
    #my $proflok = fetchProjectStats($db, \@projects);
    
    #my %projects_stats = %{fetchProjectStats($db, \@projects)};
 	print qq[
        <h2 align="center" style="font: normal 900 1.5em arial"><a href="$SCRIPT_NAME">UK10K Production Statistics</a></h2>
        <div class="centerFieldset">
        <fieldset style="width: 800px">
        <legend>Study Statistics for $ucdb</legend>
    	<table width="100%">
    	<tr>
    	<th style="color:blue;text-align:center;nowrap;width:90px">Study</th>
    	<th style="color:blue;text-align:center;nowrap">Production Statistics<br />(# samples run)</th>
    	<th style="color:blue;text-align:center;nowrap">Sample Statistics<br />(# samples qc passed)</th>
    	<th style="color:blue;text-align:center;nowrap">Sequence Statistics<br />(Raw bases/Gbp)</th>
    	</tr>        
    ];
    foreach (@projects)
    { 	
    	my $prod_count = fetchProjectProductionStats($_);
    	my $samp_count = fetchSampleProjectStats($db, $_);
    	my $seq_count = fetchSequenceProjectStats($db, $_);
    	print qq[<tr>];
        print qq[<td style="text-align:left;nowrap">$_</td>];
         if ($prod_count == -1) {
          	print qq[<td style="text-align:center">-</td>];
         }
         else {
         	print qq[<td style="text-align:center"><a href="http://intwebdev.sanger.ac.uk/Teams/Team145/dev/study-charts-json2.htm?study=$_&amp;project=$_">$prod_count</a></td>];
         }
         if ($samp_count == 0) {
          	print qq[<td style="text-align:center">-</td>];
         }
        else {
        	print qq[<td style="text-align:center"><a href="http://intwebdev.sanger.ac.uk/Teams/Team145/dev/sample-charts-json.htm?db=$db&amp;project=$_">$samp_count</a></td>];
        }
        if ($seq_count == -1) {
         	print qq[<td style="text-align:center">-</td>];
        }
        else {
        	print qq[<td style="text-align:center"><a href="http://intwebdev.sanger.ac.uk/Teams/Team145/dev/sequence-charts-json.htm?db=$db&amp;project=$_">$seq_count</a></td>];
        }
        print qq[</tr>];
    }
    print qq[
    	</table>
       	</fieldset>
       	</div>
    ];
}

sub fetchProjectProductionStats
{
	my $project = shift;
	my $dbh = DBI->connect("DBI:mysql:host=mcs10:port=3306;database=vrtrack_web_index", 
            "vreseq_ro",undef, {'RaiseError' => 1, 'PrintError'=>0});
	my $prod_stats_sql = qq[select ifnull(max(total), -1) as total from management_cumulative_stats where status in ('run complete', 'run archived') and project_name = ? and request_type like 'Paired end sequencing%'];
    my $sth = $dbh->prepare($prod_stats_sql);
    my $prod;
	if ($sth->execute($project)) {
		my $ref = $sth->fetchrow_hashref();
		$prod = $$ref{'total'};
	}
	return $prod;
}

sub fetchSampleProjectStats
{
	my $db = shift;
	my $project = shift;
	my $dbh = DBI->connect("DBI:mysql:host=mcs10:port=3306;database=$db", 
            "vreseq_ro",undef, {'RaiseError' => 1, 'PrintError'=>0});
    my $samp_stats_sql = qq[select count(distinct sa.sample_id) as total from latest_library lib, latest_lane l, latest_sample sa, latest_project pr where lib.library_id = l.library_id and sa.sample_id=lib.sample_id and sa.project_id=pr.project_id and pr.name = ? and l.npg_qc_status = 'pass' and lib.seq_centre_id = 1];
    my $sth = $dbh->prepare($samp_stats_sql);
    my $samp;
	if ($sth->execute($project)) {
		my $ref = $sth->fetchrow_hashref();
		$samp = $$ref{'total'};
	}
	return $samp;
}

sub fetchSequenceProjectStats
{
	my $db = shift;
	my $project = shift;
	my $dbh = DBI->connect("DBI:mysql:host=mcs10:port=3306;database=$db", 
            "vreseq_ro",undef, {'RaiseError' => 1, 'PrintError'=>0});
    my $seq_stats_sql=qq[SELECT ifnull(round(sum(m.raw_bases)/1e9), -1) as total from latest_sample s, latest_library lib, latest_lane l, latest_mapstats m, latest_project p where s.sample_id = lib.sample_id and lib.library_id = l.library_id and l.lane_id = m.lane_id and s.project_id = p.project_id and p.name = ?];
    my $sth = $dbh->prepare($seq_stats_sql);
    my $seq;
	if ($sth->execute($project)) {
		my $ref = $sth->fetchrow_hashref();
		$seq = $$ref{'total'};
	}
	return $seq;
}
# sub fetchProjectStats
# {
# 	my $db = shift;
# 	my $proj = shift;
# 	my @projects = @{ $proj };
# 	my $web_dbh = DBI->connect("DBI:mysql:host=mcs10:port=3306;database=vrtrack_web_index", 
#             "vreseq_ro",undef, {'RaiseError' => 1, 'PrintError'=>0});
# 	my $dbh = DBI->connect("DBI:mysql:host=mcs10:port=3306;database=vrtrack_uk10k_$db", 
#             "vreseq_ro",undef, {'RaiseError' => 1, 'PrintError'=>0});
#     my $prod_stats_sql = qq[select ifnull(max(total), -1) as total from management_cumulative_stats where status in ('run complete', 'run archived') and project_name = ? and request_type like 'Paired end sequencing%'];
#     my $samp_stats_sql = qq[select count(distinct sa.sample_id) as total from latest_library lib, latest_lane l, latest_sample sa, latest_project pr where lib.library_id = l.library_id and sa.sample_id=lib.sample_id and sa.project_id=pr.project_id and pr.name = ? and l.npg_qc_status = 'pass' and lib.seq_centre_id = 1];
#     my $seq_stats_sql=qq[SELECT ifnull(round(sum(m.raw_bases)/1e9), -1) as total from latest_sample s, latest_library lib, latest_lane l, latest_mapstats m, latest_project p where s.sample_id = lib.sample_id and lib.library_id = l.library_id and l.lane_id = m.lane_id and s.project_id = p.project_id and p.name = ?];
#     
#     my $prod_sth = $web_dbh->prepare($prod_stats_sql);
#     my $samp_sth = $dbh->prepare($samp_stats_sql);
#     my $seq_sth = $dbh->prepare($seq_stats_sql);
#  	my %proj_counts;
#  	
# # 	for my $project ( @projects ) {
# # 		my @proj_totals;
# # 		my ($prod);
# #  		if ($prod_sth->execute($project)) {
# #  			my $ref = $prod_sth->fetchrow_hashref();
# #  			push @proj_totals, $$ref{'total'};
# # 		}
# # 		if ($samp_sth->execute($project)) {
# #  			my $ref = $samp_sth->fetchrow_hashref();
# #  			push @proj_totals, $$ref{'total'};
# # 		}
# # 		if ($seq_sth->execute($project)) {
# #  			my $ref = $seq_sth->fetchrow_hashref();
# #  			push @proj_totals, $$ref{'total'};
# # 		}
# # 		$proj_counts{$project} = [@proj_totals];
# # 	}
# 	return \%proj_counts;
# #SQL to get production statistics for a project
# #select max(total) from management_cumulative_stats where status in ('run complete', 'run archived') and project_name = 'UK10K_NEURO_MUIR' and request_type like 'Paired end sequencing%'
# 
# #SQL to get sample statistics for a project
# #select count(distinct sa.sample_id) from latest_library lib, latest_lane l , latest_sample sa, latest_project pr where lib.library_id = l.library_id and sa.sample_id=lib.sample_id and sa.project_id=pr.project_id and pr.name = 'UK10K_NEURO_MUIR' and l.npg_qc_status = 'pass' and lib.seq_centre_id = 1
# 
# #SQL to get sequence stats
# #SELECT ifnull(round(sum(m.raw_bases)/1e9),-1) as raw from latest_sample s, latest_library lib, latest_lane l, latest_mapstats m, latest_project p where s.sample_id = lib.sample_id and lib.library_id = l.library_id and l.lane_id = m.lane_id and s.project_id = p.project_id and p.name = 'UK10K_COHORT_TWINSUK'
# }

# sub displayProjectLanesPage 
# {
#     my ($cgi, $vrtrack, $database, $projectID) = @_;
#     
#     my $db_id = getDatabaseID ($vrtrack, $database);
#         
#     my @projectMappers = getProjectMappers ($vrtrack, $db_id, $projectID);
#  
#  	my @libraryLanes = getLibraryLanes ($vrtrack, $db_id, $projectID); 
#     
#     my $pname = fetchProjectName($vrtrack, $projectID, $db_id);
#     print qq[
#     <h2 align="center" style="font: normal 900 1.5em arial"><a href="$SCRIPT_NAME">Map View</a></h2>
#     <h5 style="font: arial"><p><a href="$SCRIPT_NAME?mode=$DB_VIEW&amp;db=$database">$database</a>: $pname</p></h5>];
#     
#     
#     print qq[
#     <div class="centerFieldset">
#     <fieldset > 
#     <legend>Lane data</legend>
#     <table class='sortable' width="60%">
#     <tr>
#     <th>Library</th>
#     <th>Improved</th>
#     <th>Called</th>
#     <th>Name</th>
#     ];
#     
#     foreach my $mname ( sort( @projectMappers ) )
#     {
#         print qq[<th>$mname</th>];
#     }
#     print qq[</tr>];
#     
#     foreach ( @libraryLanes )
#     {
#         print qq[<tr>];
#         my @laneData = @{$_};
#         print qq[<td>$laneData[0]</td><td align="center">$laneData[1]</td><td align="center">$laneData[2]</td><td align="center"><a href="http://intwebdev.sanger.ac.uk/cgi-bin/teams/team145/qc_grind/qc_grind.pl?mode=0&lane_id=$laneData[4]&db=$database">$laneData[3]</a></td>];
#         my %lane_mappers = getLaneMappings ( $vrtrack, $db_id, $laneData[4] );
#         foreach my $mapper ( sort( @projectMappers ) ) 
#         {
#             if( $lane_mappers{ $mapper } ) { print qq[<td align="center">yes</td>]; }
#             else { print qq[<td align="center">no</td>]; }
#         }
#         print qq[</tr>];
#     }
#     print qq[
#         </table>
#         </fieldset>
#         </div>
#     ];
# }


# sub isDatabase
# {
#         my $db = shift;
#         my @dbs = fetchTrackingDatabases($vrtrack);
#         foreach( @dbs ){if( $db eq $_ ){return 1;}}
#         return 0;
# }

sub displayError
{
    my $message = $_[ 0 ];
    
    print qq[<h2>A problem occurred</h2>\n];
    print qq[<p class="error1">$message</p>\n];
    print $sw->footer();
    exit;
}

sub redirectErrorScreen
{
    my $cgi = $_[ 0 ];
    my $error = 'An unknown error occurred';
    if( @_ == 2 )
    {
        $error = $_[ 1 ];
    }
    
    my $location = "$SCRIPT_NAME?mode=$ERROR_DISPLAY&amp;error_msg=$error";
   # print $cgi->header(); 
   # print "window.location=\"$location\";\n\n";
    print $cgi->redirect( -URL => $location, -method   => 'GET', -status   => 302 );
    #print "Location: $location";
    exit;
}

sub fetchTrackingDatabases
{
	my $vrtrack = shift;
    my @dbs;
	my $sql = qq[SELECT db_name FROM tracking_database where db_name like 'vrtrack_uk10k%'];
	my $sth = $vrtrack->{_dbh}->prepare($sql);
	if ($sth->execute()) {
		my ($col1);
		$sth->bind_col(1, \$col1);
		while ($sth->fetch) {
			push @dbs, $col1;
		}
	}
	return @dbs;
}

sub fetchProjects
{
	my $db = shift;
	my $dbh = DBI->connect("DBI:mysql:host=mcs10:port=3306;database=$db", 
            "vreseq_ro",undef, {'RaiseError' => 1, 'PrintError'=>0});
    my @projects;
 	my $sql = qq[SELECT name from latest_project];
 	my $sth = $dbh->prepare($sql);
 	$sth->execute();
 	my ($name);
 	$sth->bind_col(1, \$name);
 	while ($sth->fetch) {
 		push @projects, $name;
 	}
	return \@projects;
}

# sub fetchProjectName
# {
# 
# 	my $pid = shift;
# 	my $dbid = shift;
#     my $pname;
# 	my $sql = qq[SELECT project_name FROM db_projects where project_id = ? and db_id =?];
# 	my $sth = $vrtrack->{_dbh}->prepare($sql);
# 	if ($sth->execute($pid, $dbid)) {
# 		my ($name);
# 		$sth->bind_col(1, \$name);
# 		while ($sth->fetch) {
# 			$pname = $name;
# 		}
# 	}
# 	return $pname;
# }

sub getGlobalStats
{
	my $db = shift;
	my $seqcen = shift;
	my $dbh = DBI->connect("DBI:mysql:host=mcs10:port=3306;database=vrtrack_uk10k_$db", 
            "vreseq_ro",undef, {'RaiseError' => 1, 'PrintError'=>0});
    my $sql = qq[ select count(distinct(s.name)), round(sum(m.raw_bases)/1e9), round(sum(m.rmdup_bases_mapped)/1e9), FORMAT((sum(m.rmdup_bases_mapped)/1e9)/count(distinct(s.name)),1) from latest_sample s, latest_library lib,latest_lane l, latest_mapstats m where s.sample_id = lib.sample_id and lib.seq_centre_id = ? and lib.library_id = l.library_id and l.lane_id = m.lane_id;
    ];
    my $sth = $dbh->prepare($sql);
    $sth->execute($seqcen);
    my $data = $sth->fetchall_arrayref();
	return $data->[0];
}

sub getGlobalStatsExome
{
	my $db = shift;
	my $dbh = DBI->connect("DBI:mysql:host=mcs10:port=3306;database=vrtrack_uk10k_$db", 
            "vreseq_ro",undef, {'RaiseError' => 1, 'PrintError'=>0});
#     #my $sql = qq[
#         select count(distinct(s.name)), round(sum(m.raw_bases)/1e9), round(sum(m.rmdup_bases_mapped)/1e9),  round(sum(m.target_bases_mapped)/1e9), FORMAT(avg(m.target_bases_mapped/e.target_bases),1) from latest_sample s, latest_library lib,latest_lane l, latest_mapstats m, exome_design e where s.sample_id = lib.sample_id and lib.library_id = l.library_id and l.lane_id = m.lane_id and e.exome_design_id=m.exome_design_id;
#     ];
    my $sql = qq[select count(distinct(s.name)), round(sum(m.raw_bases)/1e9), round(sum(m.rmdup_bases_mapped)/1e9),  round(sum(m.target_bases_mapped)/1e9), FORMAT((sum(m.target_bases_mapped)/e.target_bases)/count(distinct(s.name)),1) from latest_sample s, latest_library lib,latest_lane l, latest_mapstats m, exome_design e where s.sample_id = lib.sample_id and lib.library_id = l.library_id and l.lane_id = m.lane_id and e.exome_design_id=m.exome_design_id];
    
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my $data = $sth->fetchall_arrayref();
	return $data->[0];
}

# sub getDatabaseID 
# {
# 	my $vrtrack = shift;
# 	my $db = shift;
# 	my $db_id;
#     my $sql = qq[SELECT db_id FROM tracking_database where db_name = ?];
# 	my $sth = $vrtrack->{_dbh}->prepare($sql);
# 	if ($sth->execute($db)) {
# 		my ($id);
# 		$sth->bind_col(1, \$id);
# 		while ($sth->fetch) {
# 			$db_id = $id;
# 		}
# 	}
# 	return $db_id;
# }

# sub getProjectMappers
# {  
# 	my $vrtrack = shift;
# 	my $db_id = shift;
# 	my $projectID = shift; 
#     my @mappers;
#     my $sql = qq[SELECT mapper_name FROM map_view_project_mapper where db_id = ? and project_id = ?];
# 	my $sth = $vrtrack->{_dbh}->prepare($sql);
# 	if ($sth->execute($db_id, $projectID)) {
# 		my ($mapper);
# 		$sth->bind_col(1, \$mapper);
# 		while ($sth->fetch) {
# 			push @mappers, $mapper;
# 		}
# 	}
# 	return @mappers;
# }

# sub getLibraryLanes
# {  
# 	my $vrtrack = shift;
# 	my $db_id = shift;
# 	my $projectID = shift; 
#     my @libraries;
#     my $sql = qq[SELECT library_name, is_improved, is_called, lane_name, db_lane_id FROM map_view_lane where db_id = ? and project_id = ?];
# 	my $sth = $vrtrack->{_dbh}->prepare($sql);
# 	if ($sth->execute($db_id, $projectID)) {
# 		my ($lib, $imp, $cal, $lane, $id);
# 		$sth->bind_columns(\($lib, $imp, $cal, $lane, $id));
# 		while ($sth->fetch) {
# 			push @libraries, [$lib, $imp, $cal, $lane, $id];
# 		}
# 	}
# 	return @libraries;
# }

# sub getLaneMappings 
# {
# 	my $vrtrack = shift;
# 	my $db_id = shift;
# 	my $lane_id = shift;
# 	my %mappings;
# 	my $sql = qq[SELECT mapper_name FROM map_view_lane_mapper where db_id = ? and db_lane_id = ?];
# 	my $sth = $vrtrack->{_dbh}->prepare($sql);
# 	if ($sth->execute($db_id, $lane_id)) {
# 		my ($mapper);
# 		$sth->bind_col(1, \$mapper);
# 		while ($sth->fetch) {
# 			$mappings{$mapper} = 1;
# 		}
# 	}
# 	return %mappings;	
# }
