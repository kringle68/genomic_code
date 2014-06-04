=head1 NAME

UpdatePipeline::UpdateAllMetaData.pm   - Take in a list of study names, and a VRTracking database handle and update/create where IRODs differs to the tracking database

=head1 SYNOPSIS

my $pipeline = UpdatePipeline::UpdateAllMetaData->new(study_ids => \@study_ids, _vrtrack => $self->_vrtrack);
$pipeline->update();

=cut
package UpdatePipeline::UpdateAllMetaData;
use Moose;
use UpdatePipeline::IRODS;
use UpdatePipeline::VRTrack::LaneMetaData;
use UpdatePipeline::UpdateLaneMetaData;
use UpdatePipeline::VRTrack::Project;
use UpdatePipeline::VRTrack::Sample;
use UpdatePipeline::VRTrack::Library;
use UpdatePipeline::VRTrack::Lane;
use UpdatePipeline::VRTrack::File;
use UpdatePipeline::VRTrack::Study;
use UpdatePipeline::ExceptionHandler;
use Pathogens::ConfigSettings;

extends 'UpdatePipeline::CommonMetaDataManipulation';


has '_vrtrack'              => ( is => 'rw', required   => 1);
                           
has '_exception_handler'    => ( is => 'rw', lazy_build => 1,            isa => 'UpdatePipeline::ExceptionHandler' );
has '_config_settings'      => ( is => 'rw', lazy_build => 1,            isa => 'HashRef' );
has '_database_settings'    => ( is => 'rw', lazy_build => 1,            isa => 'HashRef' );
                           
has 'verbose_output'        => ( is => 'rw', default    => 0,            isa => 'Bool');
has 'update_if_changed'     => ( is => 'rw', default    => 0,            isa => 'Bool');
has 'dont_use_warehouse'    => ( is => 'ro', default    => 0,            isa => 'Bool');
has 'no_pending_lanes'      => ( is => 'ro', default    => 0,            isa => 'Bool');
has 'override_md5'          => ( is => 'ro', default    => 0,            isa => 'Bool');
has 'add_raw_reads'         => ( is => 'ro', default    => 0,            isa => 'Bool');
has 'specific_run_id'       => ( is => 'ro', default    => 0,            isa => 'Int');
has 'specific_min_run'      => ( is => 'ro', default    => 0,            isa => 'Int');
                           
has '_warehouse_dbh'        => ( is => 'rw', lazy_build => 1 );
has 'minimum_run_id'        => ( is => 'rw', default    => 1,            isa => 'Int' );
has 'environment'           => ( is => 'rw', default    => 'production', isa => 'Str');
has 'common_name_required'  => ( is => 'rw', default    => 1,            isa => 'Bool');
has 'taxon_id'              => ( is => 'rw', default    => 0,            isa => 'Int' );
has 'species_name'          => ( is => 'ro',                             isa => 'Maybe[Str]' );
has 'gs_file_path'          => ( is => 'ro',                             isa => 'Maybe[Str]' );
has 'vrtrack_lanes'         => ( is => 'ro',                             isa => 'Maybe[HashRef]' );

my $config_location = '/software/vertres/bin-external/update_pipeline/config/production';
sub _build__config_settings
{
   my ($self) = @_;
   \%{Pathogens::ConfigSettings->new(environment => $self->environment, filename => $config_location.'/config.yml')->settings()};
}

sub _build__database_settings
{
  my ($self) = @_;
  \%{Pathogens::ConfigSettings->new(environment => $self->environment, filename => $config_location.'/database.yml')->settings()};
}


sub _build__warehouse_dbh
{
  my ($self) = @_;
  Warehouse::Database->new(settings => $self->_database_settings->{warehouse})->connect;
}

sub _build__exception_handler
{
  my ($self) = @_;
  UpdatePipeline::ExceptionHandler->new( _vrtrack => $self->_vrtrack, minimum_run_id => $self->minimum_run_id, update_if_changed => $self->update_if_changed );
}


sub update
{
  my ($self) = @_;

  for my $file_metadata (@{$self->_files_metadata}) {
    if ($self->taxon_id && defined $self->species_name) {
    	$file_metadata->sample_common_name($self->species_name);
    }
    eval {
      if(UpdatePipeline::UpdateLaneMetaData->new(
          lane_meta_data => $self->_lanes_metadata->{$file_metadata->file_name_without_extension},
          file_meta_data => $file_metadata,
          common_name_required => $self->common_name_required,
          )->update_required
        )
      {
          $self->_post_populate_file_metadata($file_metadata) unless($self->dont_use_warehouse);
          $self->_update_lane($file_metadata);
      }
    };
    if(my $exception = Exception::Class->caught())
    {
      $self->_exception_handler->add_exception($exception,$file_metadata->file_name_without_extension);
    }
    if ( $self->vrtrack_lanes && $self->vrtrack_lanes->{$file_metadata->file_name_without_extension} ) {
		delete $self->vrtrack_lanes->{$file_metadata->file_name_without_extension};
	}	
  }
  if ( $self->vrtrack_lanes && keys %{$self->vrtrack_lanes} > 0 ) {
	  $self->_withdraw_lanes;
  }
  $self->_exception_handler->print_report($self->verbose_output);

  1;
}

sub _update_lane
{
  my ($self, $file_metadata) = @_;
  eval {
    my $vproject = UpdatePipeline::VRTrack::Project->new(name => $file_metadata->study_name, external_id => $file_metadata->study_ssid, _vrtrack => $self->_vrtrack)->vr_project();
    if(defined($file_metadata->study_accession_number))
    {
      my $vstudy   = UpdatePipeline::VRTrack::Study->new(accession => $file_metadata->study_accession_number, _vr_project => $vproject)->vr_study();
      $vproject->update;
    }
    
    my $vr_sample = UpdatePipeline::VRTrack::Sample->new(
      common_name_required => $self->common_name_required,
      name => $file_metadata->sample_accession_number,  
      external_id => $file_metadata->sample_ssid, 
      common_name => $file_metadata->sample_common_name, 
      accession => $file_metadata->sample_accession_number,
      supplier_name => $file_metadata->supplier_name,
      cohort_name => $file_metadata->cohort_name,
      control => $file_metadata->control,
      #use_supplier_name => $self->use_supplier_name,
      taxon_id => $self->taxon_id,
      _vrtrack => $self->_vrtrack,
      _vr_project => $vproject)->vr_sample();
      
    my $vr_library = UpdatePipeline::VRTrack::Library->new(
      name                 => $file_metadata->library_name,
      external_id          => $file_metadata->library_ssid,
      library_tag_sequence => $file_metadata->beadchip_section,
      _vrtrack             => $self->_vrtrack,
      _vr_sample           => $vr_sample)->vr_library();

    my $vr_lane = UpdatePipeline::VRTrack::Lane->new(
      name          => $file_metadata->file_name_without_extension,
      accession     => $file_metadata->lane_accession,
      storage_path  => $file_metadata->storage_path,
      _vrtrack      => $self->_vrtrack,
      _vr_library   => $vr_library)->vr_lane();

    UpdatePipeline::VRTrack::File->new(
      name => $file_metadata->file_name,
      file_type => $file_metadata->file_type_number($file_metadata->file_type), 
      md5 => $file_metadata->file_md5 , 
      override_md5 => $self->override_md5, 
      _vrtrack => $self->_vrtrack,
      _vr_lane => $vr_lane)->vr_file();
      
  };
  if(my $exception = Exception::Class->caught())
  {
    $self->_exception_handler->add_exception($exception, $file_metadata->file_name_without_extension);
  }
}

sub _post_populate_file_metadata
{
  my ($self, $file_metadata) = @_;
  Warehouse::FileMetaDataPopulation->new(file_meta_data => $file_metadata, _dbh => $self->_warehouse_dbh)->post_populate();
}

sub _withdraw_lanes
{
	#Subroutine that withdraws lanes that have been deleted from iRODS, but remain in the database.
	#This can only called if the -wdr flag is set on the command lane explicitly.
	my ($self) = @_;
  	foreach my $lane ( keys %{$self->vrtrack_lanes} ) {
		my $lane_to_withdraw = VRTrack::Lane->new($self->_vrtrack, $self->vrtrack_lanes->{$lane});
		$lane_to_withdraw->is_withdrawn(1);
		$lane_to_withdraw->update;	
		print "The lane $lane has been withdrawn as it has been deleted from iRODS\n";
	}
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

