#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'uninitialized';
use DBI;
use JSON;
use CGI qw(:standard);

my $cgi = CGI->new();
my $study = $cgi->param('study');
my $reqtype = $cgi->param('type');
my $cumul = $cgi->param('cumul');

$study ||= "UK10K_NEURO_MUIR";
$reqtype = "Paired end sequencing" unless defined $reqtype;
$reqtype = '%'.$reqtype;
$cumul = 1 unless defined $cumul;

my $web_dbh = DBI->connect("dbi:mysql:host=mcs10;port=3306;database=vrtrack_web_index", "vreseq_rw", "t3aml3ss", {'RaiseError' => 1, 'PrintError'=>0});

my $jsonarr = get_cumul_stats($web_dbh, $study, $reqtype); 
if ($cumul){
    $jsonarr = get_cumul_stats($web_dbh, $study, $reqtype); 
}
else {
    $jsonarr = get_cumul_stats($web_dbh, $study, $reqtype); 
}

my $json = new JSON;

my $jsontxt = $json->encode($jsonarr);
# unquote big numbers - no idea how to fix this in JSON module
$jsontxt =~ s/"(\d+)"/$1/g;

print header('application/json');
print "$jsontxt\n";

# done.


# for some reason, joining the status dictionary in to the query makes it take about 3 orders of magnitude longer.
# Pull this and do the join in perl
# It's a bit filthy to load both ends into the same hash, but they shouldn't collide (famous last words)


# sub get_running_stats {
#     my ($dbh, $study, $reqtype) = @_;
# 
#     my $statushash = get_status_hash;
#     my $statuskeys = join ",", @$statushash{("run pending","run complete", "run cancelled","analysis in progress", "analysis complete", "archival pending", "run archived")};
# 
#     my $sth = $wh2_dbh->prepare_cached(<<SQL);
#     select unix_timestamp(date(n.date))*1000 as UTC, id_run_status_dict, count(*) from npg_information npg, npg_run_status n, requests r where r.study_name = ? and request_type like ? and r.is_current=1 and r.state != "cancelled" and r.internal_id = npg.request_id and npg.id_run = n.id_run and id_run_status_dict in ($statuskeys) group by UTC, n.id_run_status_dict order by UTC;
# SQL
# 
#     my($utc, $state_id, $count);
#     $sth->execute($study, $reqtype);
#     $sth->bind_columns(undef, \$utc, \$state_id, \$count);
# 
#     my %jsonhash = ('Running' => [],
#                     'Analysing' => [],
#                     'Archiving' => [],
#                     );
# 
#     # data arrive in date order, so can calculate running total
#     my ($run_tot, $analysis_tot, $archival_tot) = (0,0,0);
#     while ($sth->fetch) {
#         my $state = $statushash->{$state_id};
#         if($state eq 'run pending'){
#             $run_tot += $count;
#             push @{$jsonhash{'Running'}}, [$utc,$run_tot];
#         }
#         elsif ($state eq 'run complete'){
#             $run_tot -= $count;
#             push @{$jsonhash{'Running'}}, [$utc,$run_tot];
#         }
#         elsif ($state eq 'run cancelled'){
#             $run_tot -= $count;
#             push @{$jsonhash{'Running'}}, [$utc,$run_tot];
#         }
#         elsif($state eq 'analysis in progress'){
#             $analysis_tot += $count;
#             push @{$jsonhash{'Analysing'}}, [$utc,$analysis_tot];
#         }
#         elsif ($state eq 'analysis complete'){
#             $analysis_tot -= $count;
#             push @{$jsonhash{'Analysing'}}, [$utc,$analysis_tot];
#         }
#         elsif($state eq 'archival pending'){
#             $archival_tot += $count;
#             push @{$jsonhash{'Archiving'}}, [$utc,$archival_tot];
#         }
#         elsif ($state eq 'run archived'){ 
#             $archival_tot -= $count;
#             push @{$jsonhash{'Archiving'}}, [$utc,$archival_tot];
#         }
#         else {
#             die "state $state not recognised\n";
#         }
#     }
# 
#     my @jsonarr;
#     foreach ('Running','Analysing','Archiving'){
#         push @jsonarr, {name => $_, data => $jsonhash{$_}};
#     }
#     return \@jsonarr;
# }


sub get_cumul_stats {
    my ($dbh, $study, $reqtype) = @_;

    # get requests
    my ($current) = $dbh->selectrow_array("select unix_timestamp(date(NOW()))*1000 from dual");
    my $sth = $web_dbh->prepare_cached(<<SQL);
    select date*1000, total from management_cumulative_stats where status = 'requested' and project_name =? and request_type like ? order by date;
SQL

    my %jsonhash = (
                    'Requested' => [],
                    'Run' => [],
                    'Archived' => [],
                    );

    my($utc, $count);
    $sth->execute($study, $reqtype);
    $sth->bind_columns(undef, \$utc, \$count);

    my $req_tot = 0;
    my $max_curr = 0;
    while ($sth->fetch) {
    	if ($count > $max_curr) { $max_curr = $count; }
        push @{$jsonhash{'Requested'}}, [$utc,$count];
    }
    push @{$jsonhash{'Requested'}}, [$current,$max_curr];
    # get run stats
    #my @statusarray = ("run complete", "analysis complete","run archived");
    #my $statuskeys = join ",", ("'run complete'", "'analysis complete'", "'run archived'");

    $sth = undef;
    $sth = $web_dbh->prepare_cached(<<SQL);
    select date*1000, status, total from management_cumulative_stats where status in ('run complete', 'run archived') and project_name =? and request_type like ? order by date;
SQL

    my $state;
    $utc = $count = undef;
    $sth->execute($study, $reqtype);
    $sth->bind_columns(undef, \$utc, \$state, \$count);

    # data arrive in date order, so can calculate running total
    my $max_comp = 0;
    my $max_arch = 0;
    while ($sth->fetch) {
        if ($state eq 'run complete'){
            if ($count > $max_comp) { $max_comp = $count; }
            push @{$jsonhash{'Run'}}, [$utc,$count];
        }
        elsif ($state eq 'run archived'){ 
            if ($count > $max_arch) { $max_arch = $count; }
            push @{$jsonhash{'Archived'}}, [$utc,$count];
        }
        else {
            die "state $state not recognised\n";
        }
    }
    push @{$jsonhash{'Run'}}, [$current,$max_comp];
    push @{$jsonhash{'Archived'}}, [$current,$max_arch];
    
    my @jsonarr;
    foreach ('Requested','Run','Archived'){
        push @jsonarr, {name => $_, data => $jsonhash{$_}};
    }
    return \@jsonarr;
}
