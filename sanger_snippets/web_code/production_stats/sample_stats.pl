#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'uninitialized';
use DBI;
use JSON;
use CGI qw(:standard);

my $cgi = CGI->new();
my $db = $cgi->param('db');
my $study = $cgi->param('study');
my $is_cohort = ($db =~ /cohort$/ ? 1 : 0);
my $cutoff = ($is_cohort ? 12 : 4);

my $jsonarr = get_sample_stats($db, $study, $cutoff); 
my $json = new JSON;
my $jsontxt = $json->encode($jsonarr);
# unquote big numbers - no idea how to fix this in JSON module
$jsontxt =~ s/"(\d+)"/$1/g;
print header('application/json');
print "$jsontxt\n";

sub get_sample_stats {
    my ($db, $study, $cutoff) = @_;
    my $dbh = DBI->connect("DBI:mysql:host=mcs10:port=3306;database=$db", "vreseq_ro",undef, {'RaiseError' => 1, 'PrintError'=>0});
    #my $sql = "select a.UTC, count(*) from (select min(unix_timestamp(date(l.run_date))*1000) as UTC, lib.sample_id as sampid from latest_library lib, latest_lane l, latest_seq_request s where lib.library_id = l.library_id and l.seq_request_id = s.seq_request_id and s.seq_status = 'passed' group by lib.sample_id order by l.run_date) a group by a.UTC order by a.UTC";
    
    #my $sql = "select a.UTC, count(*) from (select min(unix_timestamp(date(l.run_date))*1000) as UTC, lib.sample_id as sampid from latest_library lib, latest_lane l, latest_seq_request s".($study eq "All" ? '' : ", latest_sample sa, latest_project pr")." where lib.library_id = l.library_id and l.seq_request_id = s.seq_request_id ".($study eq "All" ? '' : "and sa.sample_id=lib.sample_id and sa.project_id=pr.project_id and pr.name = ?")." and s.seq_status = 'passed' group by lib.sample_id order by l.run_date) a group by a.UTC order by a.UTC";
    
    my $sql = "select a.UTC, count(*) from (select min(unix_timestamp(date(l.run_date))*1000) as UTC, lib.sample_id as sampid from latest_library lib, latest_lane l".($study eq "All" ? '' : ", latest_sample sa, latest_project pr")." where lib.library_id = l.library_id ".($study eq "All" ? '' : "and sa.sample_id=lib.sample_id and sa.project_id=pr.project_id and pr.name = ?")." and l.npg_qc_status = 'pass'".($is_cohort ? " and lib.seq_centre_id = 1" : '')." group by lib.sample_id order by l.run_date) a group by a.UTC order by a.UTC";
    
    my ($current) = $dbh->selectrow_array("select unix_timestamp(date(NOW()))*1000 from dual");
    
#   my $datesql = "select distinct unix_timestamp(date(run_date))*1000 from latest_lane where run_date is not null order by date(run_date)";
#     
#   my $completesql = "select count(*) from (select lib.sample_id as sample, round(sum(m.rmdup_bases_mapped)/1e9) as mapped from latest_library lib, latest_lane l, latest_mapstats m where lib.library_id = l.library_id and l.lane_id = m.lane_id and unix_timestamp(date(run_date))*1000 <= ? group by lib.sample_id) a where a.mapped >= ?";

	my $compsql = "select z.UTC, count(*) from (select distinct unix_timestamp(date(run_date))*1000 as UTC from latest_lane where run_date is not null order by date(run_date)) z, (select lib.sample_id as sample, round(sum(m.rmdup_bases_mapped)/1e9) as mapped, unix_timestamp(date(run_date))*1000 as treff from latest_library lib, latest_lane l, latest_mapstats m".($study eq "All" ? '' : ", latest_sample sa, latest_project pr")." where lib.library_id = l.library_id and lib.seq_centre_id = 1 and run_date is not null and l.lane_id = m.lane_id ".($study eq "All" ? '' : "and sa.sample_id=lib.sample_id and sa.project_id=pr.project_id and pr.name = ?")."group by lib.sample_id) y where z.UTC = y.treff and y.mapped >= ? group by z.UTC order by z.UTC";
    
    my $sth = $dbh->prepare($sql);
#     my $datesth = $dbh->prepare($datesql);
#     my $compsth = $dbh->prepare($completesql);
my $sample_key = "Samples with qc-passed seq";
my $complete_key = "Complete samples (>$cutoff Gbp mapped)";
    my %jsonhash = (
                    $sample_key => [],
                    $complete_key => [],
                    );
    my($utc, $sampcount);
    if ($study eq "All") {
    	$sth->execute();
    }
    else {
    	$sth->execute($study);
    }		
    $sth->bind_columns(undef, \$utc, \$sampcount);
    my $samp_tot = 0;
    while ($sth->fetch) {
        $samp_tot += $sampcount;
        push @{$jsonhash{$sample_key}}, [$utc,$samp_tot];
    }
    push @{$jsonhash{$sample_key}}, [$current,$samp_tot];
    
    $samp_tot=0;
    $sth = $dbh->prepare($compsql);
    if ($study eq "All") {
    	$sth->execute($cutoff);
    }
    else {
    	$sth->execute($study, $cutoff);
    }    
    $sth->bind_columns(undef, \$utc, \$sampcount);
    while ($sth->fetch) {
        $samp_tot += $sampcount;
        push @{$jsonhash{$complete_key}}, [$utc,$samp_tot];
    }
    push @{$jsonhash{$complete_key}}, [$current,$samp_tot];
# equalise endpoints

    if ($jsonhash{$sample_key}->[-1][0] > $jsonhash{$complete_key}->[-1][0]){
        push @{$jsonhash{$complete_key}}, [$jsonhash{$sample_key}->[-1][0],
                                           $jsonhash{$complete_key}->[-1][1]
                                           ];
    }
    elsif ($jsonhash{$complete_key}->[-1][0] > $jsonhash{$sample_key}->[-1][0]){
        push @{$jsonhash{$sample_key}}, [$jsonhash{$complete_key}->[-1][0],
                                           $jsonhash{$sample_key}->[-1][1]
                                           ];
    }
    my @jsonarr;
    foreach ($sample_key, $complete_key){
        push @jsonarr, {name => $_, data => $jsonhash{$_}};
    }
    return \@jsonarr;
}
