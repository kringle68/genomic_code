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

use SangerPaths qw(core team145);
use SangerWeb;
use lib './modules';
use VertRes::Utils::VRTrackFactory;
use VertRes::QCGrind::ViewUtil_dev;

my $utl = VertRes::QCGrind::ViewUtil_dev->new();

my $title = 'Pending View';

my $sw  = SangerWeb->new({
    'title'   => $title,
    'banner'  => q(),
    'inifile' => SangerWeb->document_root() . q(/Info/header.ini),
    'jsfile'  => ['http://jsdev.sanger.ac.uk/prototype.js','http://jsdev.sanger.ac.uk/jquery-1.4.2.min.js','http://www.sanger.ac.uk/modelorgs/mousegenomes/jquery.coolfieldset.js'],
    'style'   => $utl->{CSS},
});

my $cgi = $sw->cgi();

my $script = $utl->{SCRIPTS}{PENDING_REQ_VIEW};

print $sw->header();
$utl->displayDatabasesPage($title,$cgi,$script,1,1);
print $sw->footer();
exit;
