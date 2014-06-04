=head1 NAME

Lane.pm   - Link between the input meta data for a lane and the VRTracking table of the same name. 

=head1 SYNOPSIS

use UpdatePipeline::VRTrack::Lane;
my $lane = UpdatePipeline::VRTrack::Lane->new(
  name         => '1234_5#6',
  total_reads  => 1000,
  npg_qc_status => 'pass',
  _vrtrack     => $vrtrack_dbh,
  _vr_library  => $_vr_library
  );

my $vr_lane = $lane->vr_lane();

=cut


package UpdatePipeline::VRTrack::Lane;
use VRTrack::Lane;
use Moose;

has 'name'          => ( is => 'rw', isa => 'Str',  required   => 1 );
has 'accession'     => ( is => 'rw', isa => 'Maybe[Str]' );
has 'storage_path'  => ( is => 'rw', isa => 'Maybe[Str]');
has '_vrtrack'      => ( is => 'rw',                required   => 1 );
has '_vr_library'   => ( is => 'rw',                required   => 1 );

has 'vr_lane'       => ( is => 'rw',                lazy_build => 1 );

sub _build_vr_lane
{
  my ($self) = @_;
  
  my $vlane = VRTrack::Lane->new_by_name( $self->_vrtrack, $self->name);
  unless(defined($vlane))
  {
      $vlane = $self->_vr_library->add_lane($self->name); 
  }
  UpdatePipeline::Exceptions::CouldntCreateLane->throw( error => "Couldnt create lane with name ".$self->name."\n" ) if(not defined($vlane));
  
  # check to see if the library has been updated
  if($vlane->library_id != $self->_vr_library->id)
  {
    $vlane->library_id($self->_vr_library->id);
  }
  $vlane->hierarchy_name( $self->name );
  $vlane->acc( $self->accession ) if ( $self->accession );
  $vlane->storage_path( $self->storage_path ) if ( $self->storage_path );
  $vlane->raw_reads(0);
  $vlane->raw_bases(0);
  $vlane->is_paired(0);
   
  $vlane->update;
  
  return $vlane;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;
