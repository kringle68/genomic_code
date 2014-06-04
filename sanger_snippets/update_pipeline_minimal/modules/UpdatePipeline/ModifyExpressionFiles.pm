=head1 NAME

UpdatePipeline::ModifyExpressionFiles.pm   - Modify the imported Genome Studio expression data files for use in the vrpie pluritest pipeline

=head1 SYNOPSIS

my $modify = UpdatePipeline::ModifyExpressionFiles->new(_vrtrack => $self->_vrtrack);
$modify->update();

=cut
package UpdatePipeline::ModifyExpressionFiles;
use File::Compare qw(compare_text);
use File::Basename;
use File::Spec;
use Moose;

has '_vrtrack'              => ( is => 'rw', required   => 1);

sub update
{
  	my ($self) = @_;
  
	my $sql_select_cohort_names = "SELECT distinct name from individual";
	my $sql_select_path_uuid = "SELECT distinct n.storage_path, n.acc FROM latest_library l, latest_sample s, individual i, latest_lane n WHERE n.library_id = l.library_id and l.sample_id = s.sample_id and s.individual_id = i.individual_id and i.name = ?";
	my $sql_select_sample_mapping = "SELECT s.name, l.library_tag_sequence, i.name, n.acc, s.note_id, n.name FROM latest_library l, latest_sample s, individual i, latest_lane n WHERE n.library_id = l.library_id and l.sample_id = s.sample_id and s.individual_id = i.individual_id and n.acc = ? order by n.acc, i.name, s.note_id desc, l.library_tag_sequence asc";
	my $sql_update_storage_path = "UPDATE lane set storage_path = ? where name = ? and latest = 1"; 

	my $sth_cohort = $self->_vrtrack->{_dbh}->prepare($sql_select_cohort_names);
	my $sth_path = $self->_vrtrack->{_dbh}->prepare($sql_select_path_uuid);
	my $sth_map = $self->_vrtrack->{_dbh}->prepare($sql_select_sample_mapping);
	my $sth_update = $self->_vrtrack->{_dbh}->prepare($sql_update_storage_path);

	my $header_target = 'TargetID';
	my $header_line;
	my %analysed_files;
	my @cohorts;

	$sth_cohort->execute();
	while ( (my $cohort) = $sth_cohort->fetchrow_array()) {
		push @cohorts, $cohort;
	}

	for my $cohort ( @cohorts ) {
		$sth_path->execute($cohort);
		while (my ($path, $uuid) = $sth_path->fetchrow_array()) {
			my %expression_order;
			my %sample_lanes;
			my $profile_sample;
        	my $expression_dir = (split( "downloads", $path))[0];
			my $procdir = File::Spec->catpath( '', $expression_dir, $cohort );	
			system "mkdir $procdir" unless -e $procdir;	
			
			#Produce mapping file for the cohort
			my $mapping_file = File::Spec->catpath( '', $procdir, 'expression_mapping.txt');
			open MAP, ">", $mapping_file;
	    	$sth_map->execute($uuid);
	    	while ( my ($sample, $tag, $cohort_chk, $uuid, $control, $lane) = $sth_map->fetchrow_array()) {
				if ( $cohort eq $cohort_chk ) {
					$sample = $sample."_CTRL" if $control == 1;
					$expression_order{$tag} = $sample;
					$sample_lanes{$sample} = $lane;
					print MAP "$tag\t$sample\n";
				}
			}
	    	close MAP;		

	    	#Get current annotation file. if it exists...
	    	my $exp_annot_file = File::Spec->catpath( '', $expression_dir, 'genome_studio_expression_annotation.txt');
			my @exp_files = <$path/*>;
			my $sample_profile;

			foreach my $exp_file (@exp_files) {
				if ( $exp_file =~ m/annotation.txt$/ && !$analysed_files{$exp_file} ) {
					if ( !-f $exp_annot_file ) {  #No file, so create one....
						open ANNOT, "<", $exp_file;
						open ANOUT, ">", $exp_annot_file;
						my $body_text = 0;
						while ( <ANNOT> ) {
							$body_text = 1 if $_ =~ /^$header_target/;
							print ANOUT $_ if $body_text;
						}
						close ANOUT;
						close ANNOT;
					}
					elsif ( compare_text( $exp_annot_file, $exp_file ) ) { #Files not identical, so perform intersection
						my %current_fields;
						my @new_fields;
						open CURRENT, "<", $exp_annot_file;
						while ( <CURRENT> ) {
							if ( $_ =~ /^$header_target/ ) {
								$header_line = $_;
							}
							else {
								$current_fields{$_} = 1;
							}
						}
						close CURRENT;
						open NEW, "<", $exp_file;
						while ( <NEW> ) {
							push @new_fields, $_ unless $_ =~ /^$header_target/;
						}
						close NEW;
						# the intersection of current and new:
						my @intersection = grep( $current_fields{$_}, @new_fields );
						open ANOUT, ">", $exp_annot_file;
						print ANOUT $header_line;
						for my $annot ( @intersection ) {
							print ANOUT $annot;
						}
						close ANOUT;					
					}
					$analysed_files{$exp_file} = 1; 
				}
				elsif ( $exp_file =~ m/Sample_Probe_Profile.txt/ ) {
					$sample_profile = $exp_file;
				}
			}
			
			for my $analysis_tag ( keys %expression_order ) {
				my $sample = $expression_order{$analysis_tag};
				my $lane = $sample_lanes{$sample};
				my $profile_file = File::Spec->catpath( '', $procdir, $sample."_$analysis_tag.txt");
				open POUT, ">", $profile_file;
				if ($sample_profile =~ /\.gz$/) {
					open PRFL, "gunzip -c $sample_profile |";
				}
				else {
					open PRFL , $sample_profile;
				}
				my $body_text = 0;
				my @profile_order;	
				my @head_line;
				while ( <PRFL> ) {
					chomp;
					my @line = split("\t", $_);
					if ( $_ =~ /^$header_target/ ) {
						$body_text = 1;
						@head_line = split("\t", $_);
						for ( my $i = 2; $i <= $#head_line; $i++ ) {
							if ( $head_line[$i] =~ m/[0-9]{10}_$analysis_tag/ ) {
								push @profile_order, $i;
							}
						}
					}
					if ( $body_text ) {
						print POUT "$line[0]\t$line[1]";
				    	for my $key ( @profile_order ) {
							print POUT "\t$line[$key]";
						}
						print POUT "\n";
					}
				}
				close PRFL;
				close POUT;
				$sth_update->execute($profile_file, $lane);
			}
		}
	}
	1;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

