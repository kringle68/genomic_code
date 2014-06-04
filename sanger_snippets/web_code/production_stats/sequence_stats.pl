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

$db||='total_dbs';

my $jsonarr;
if ( $db eq 'total_dbs' ) {
	$jsonarr = get_total_stats();
}
else {
	$jsonarr = get_sequence_stats($db, $study); 
}
my $json = new JSON;
my $jsontxt = $json->encode($jsonarr);
# unquote big numbers - no idea how to fix this in JSON module
$jsontxt =~ s/"(\d+)"/$1/g;
print header('application/json');
print "$jsontxt\n";

sub get_sequence_stats {
    my ($db, $study) = @_;
    my $dbh = DBI->connect("DBI:mysql:host=mcs10:port=3306;database=$db", "vreseq_ro",undef, {'RaiseError' => 1, 'PrintError'=>0});
    my $sql = "select a.raw, a.rmdp, a.UTC, a.latest_date from (SELECT round(sum(m.raw_bases)/1e9) as raw, round(sum(m.rmdup_bases_mapped)/1e9) as rmdp, unix_timestamp(date(l.run_date))*1000 as UTC, unix_timestamp(date(NOW()))*1000 as latest_date from latest_sample s, latest_library lib, latest_lane l, latest_mapstats m".($study eq "All" ? '' : ", latest_project p")." where s.sample_id = lib.sample_id and lib.library_id = l.library_id and l.lane_id = m.lane_id and l.run_date is not null".($study eq "All" ? '' : " and s.project_id = p.project_id and p.name = ?")." group by date(l.run_date)
    UNION 
    SELECT round(sum(m.raw_bases)/1e9) as raw, round(sum(m.rmdup_bases_mapped)/1e9) as rmdp, unix_timestamp(date(l.changed))*1000 as UTC, unix_timestamp(date(NOW()))*1000 as latest_date from latest_sample s, latest_library lib, latest_lane l, latest_mapstats m".($study eq "All" ? '' : ", latest_project p")." where s.sample_id = lib.sample_id and lib.library_id = l.library_id and l.lane_id = m.lane_id and l.run_date is null".($study eq "All" ? '' : " and s.project_id = p.project_id and p.name = ?")." group by date(l.changed)) a order by a.UTC";
    
    my $sth = $dbh->prepare($sql);
     
    my %jsonhash = (
                    'Raw bases (Gbp)' => [],
                    'Rmdup bases (Gbp)' => [],
                    );

    my($utc, $rawcount, $rmdcount, $latest);
    if ($study eq "All") {
    	$sth->execute();
    }
    else {
    	$sth->execute($study, $study);
    }		
    $sth->bind_columns(undef, \$rawcount, \$rmdcount, \$utc, \$latest);

    my $raw_tot = 0;
    my $rmd_tot = 0;
    my $currentutc = 0;
    while ($sth->fetch) {
        $raw_tot += $rawcount;
        $rmd_tot += $rmdcount;
        if ($utc != $currentutc) {
        	push @{$jsonhash{'Raw bases (Gbp)'}}, [$utc,$raw_tot];
        	push @{$jsonhash{'Rmdup bases (Gbp)'}}, [$utc,$rmd_tot];
        }
        $currentutc = $utc;	
    }
    push @{$jsonhash{'Raw bases (Gbp)'}}, [$latest,$raw_tot];
    push @{$jsonhash{'Rmdup bases (Gbp)'}}, [$latest,$rmd_tot];    
    my @jsonarr;
    foreach ('Raw bases (Gbp)','Rmdup bases (Gbp)'){
        push @jsonarr, {name => $_, data => $jsonhash{$_}};
    }
    return \@jsonarr;
}

sub get_total_stats {
    my $db = 'vrtrack_web_index';
    my $dbh = DBI->connect("DBI:mysql:host=mcs10:port=3306;database=$db", "vreseq_ro",undef, {'RaiseError' => 1, 'PrintError'=>0});
    my $sql = "select utc*1000, raw_seq, rmdp, unix_timestamp(date(NOW()))*1000 as latest_date from management_all_sequences order by utc";
    
    my $sth = $dbh->prepare($sql);
     
    my %jsonhash = (
                    'Raw bases (Gbp)' => [],
                    #'Rmdup bases (Gbp)' => [],
                    );

    my($utc, $rawcount, $rmdcount, $latest);
    
    $sth->execute();
    $sth->bind_columns(undef, \$utc, \$rawcount, \$rmdcount, \$latest);

    my $raw_tot = 0;
    my $rmd_tot = 0;
    my $currentutc = 0;
    while ($sth->fetch) {
        $raw_tot += $rawcount;
        $rmd_tot += $rmdcount;
        if ($utc != $currentutc) {
        	push @{$jsonhash{'Raw bases (Gbp)'}}, [$utc,$raw_tot];
        	#push @{$jsonhash{'Rmdup bases (Gbp)'}}, [$utc,$rmd_tot];
        }
        $currentutc = $utc;	
    }
    push @{$jsonhash{'Raw bases (Gbp)'}}, [$utc,$raw_tot];
    my @jsonarr;
    foreach ('Raw bases (Gbp)'){
        push @jsonarr, {name => $_, data => $jsonhash{$_}};
    }
    return \@jsonarr;    
}