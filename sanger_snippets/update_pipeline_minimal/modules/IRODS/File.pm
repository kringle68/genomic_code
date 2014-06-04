=head1 NAME

File.pm   - Represents a single file with some metadata

=head1 SYNOPSIS

use IRODS::File;
my $file = IRODS::File->new(
  file_location => '/seq/1234/1234_5.bam'
  );

my %file_metadata = $file->file_attributes();

=cut

package IRODS::File;
use Moose;
use File::Spec;
use File::Basename;
extends 'IRODS::Common';

has 'file_location'                 => ( is => 'rw', isa => 'Str',  required   => 1 );
has 'file_type'                     => ( is => 'rw', isa => 'Maybe[Str]');

has 'file_attributes'               => ( is => 'rw', isa => 'HashRef', lazy_build => 1 );
has 'file_name'                     => ( is => 'rw', isa => 'Str', lazy_build => 1 );
has 'file_containing_irods_output'  => ( is => 'rw', isa => 'Str'); # Used for testing, pass a file with output from IRODS

sub _build_file_attributes
{
   my ($self) = @_;
   my %file_attributes;
   my $irods_stream = $self->_stream_location() ;
   $file_attributes{file_name}  = $self->file_name();
   $file_attributes{file_name_without_extension} = $self->_file_name_without_extension($self->file_name());

   open( my $irods, $irods_stream ) or return  \%file_attributes;
   
   my $attribute = '';
   my @identifiers;
   while (<$irods>) {
       if (/^attribute: (.+)$/) { 
		   if ( /dcterms:identifier/ ) {
			   $attribute = '';
		   }
		   else {
			   $attribute                    = $1; 
		   }
	   }
       if (/^value: (.+)$/) {
		   if ( $attribute ) { 
			   $file_attributes{$attribute} = $1; 
		   }
		   else {
			   push @identifiers, $1;
		   }
	   }
   }
   close $irods;
   
   if ( defined ($file_attributes{sample}) ) {
	   if ( $self->file_type eq 'gtc' ) {
	       foreach ( @identifiers ) {
		       next if $_ eq $file_attributes{sample};
		       $file_attributes{long_sample} = $_ if $_ =~ m/$file_attributes{sample}/;
		   }
	   }
	   else {
		   my $long_sample = $file_attributes{sample};
		   $long_sample = $long_sample."_$file_attributes{beadchip}" if defined $file_attributes{beadchip};
		   $long_sample = $long_sample."_$file_attributes{beadchip_section}" if defined $file_attributes{beadchip_section};
		   $file_attributes{long_sample} = $long_sample;
	   }
   }		   
	   
   if (! defined($file_attributes{md5})) {
       $file_attributes{md5} = $self->_get_md5_from_icat;
   }
   
   return \%file_attributes;
}

sub _build_file_name
{
  my ($self) = @_; 
  
  my ($volume,$directories,$file_name) = File::Spec->splitpath( $self->file_location );
  
  return $file_name;
}

sub _file_name_without_extension
{
   my ($self) = @_; 
   my ($filename) = fileparse($self->file_name,'\..*'); 
   return $filename;
}



sub _stream_location
{
  my ($self) = @_; 
  
  if($self->file_containing_irods_output)
  {
    # Used for testing, pass a file with output from IRODS
    return $self->file_containing_irods_output;
  }
  
  return $self->bin_directory . "imeta ls -d ".$self->file_location." |";
}

sub _get_md5_from_icat
{
  my ($self) = @_; 
  
  my $cmd = $self->bin_directory . "ichksum ".$self->file_location;
  open(my $irods_md5_fh, '-|', $cmd);
  my $md5 = <$irods_md5_fh>;
  chomp $md5;
  $md5 =~s/.*\s//;
  return $md5;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;
