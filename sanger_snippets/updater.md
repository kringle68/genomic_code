Title:   HipSci Q1 pilot tracking updater from iRODS metadata
Author:  John Maslen
Date:    Mon 22 Apr 2013
Version: 1.0
Comment: This document describes the sample-level metadata used to populate the tracking database for the HipSci pilot project

## Tracking database updater from iRODS metadata ##

The updater currently works on the pilot idat and gtc files available in iRODS to populate the HipSci tracking database, which is vrtrack_hipsci_q1_pilot. It has been created to also work with tsv/csv files as they become available, as we anticipate that the metadata will be available for these files in iRODS, with the addition of cell line/type information that will probably be associated with the lane data.

## Database tables and iRODS metadata keys ##


| Table		|	Parameter (column)		|	iRODS metadata / file name		|	Comments |
| :----------------------	| :--------------------------	| :----------------------------------	| :--------------------------------------------
| project		|	ssid |	study_id |	|
| |	name	|		study_title | |
| | hierarchy_name	|		study_title | |
| sample | ssid	|			sample_id	| |			
| |		name	|			dcterms:identifier	 | E.g. 271298_B03_hipscigt5466711 [3] |
| |		hierarchy_name		|	dcterms:identifier	 | |	
| library	| ssid			|	beadchip and sample_id	|	Last 4 digits of beadchip + last 3 digits of sample_id |
| |		name |				beadchip and sample_id	|		(beadchip)_(sample_id), e.g. 9274735028_1559359 [1] | |		
| |		hierarchy_name		|	beadchip and sample_id		|	(beadchip)_(sample_id), e.g. 9274735028_1559359 | |
| lane	|	name		|	file name without extension	|	E.g. 9273354128_R01C02. [2] | |
| |		hierarchy_name		|	file name without extension | E.g. 9273354128_R01C02. |			
| |		accession           |  analysis_uuid   |  This links the binary files to the Genome Studio genotyping tsv file | |							
| file	| name				| file name | |
| |		hierarchy_name		|	file name | | 
| |		md5		|		md5	| |	
| individual | name		|		supplier_name from warehouse | |
| |		hierarchy_name	|		supplier_name from warehouse | |
| |		acc			|	sample | |
		

####Notes####
- [1] Beadchip id is not unique per sample, so it is made this way by appending the sample_ssid.
- [2] This is a combination of beadchip and beadchip_section, which gives a unique coordinate per sample. The beadchip_section is not yet deployed on the metadata, but will be used in future.
- [3] This is the plate barcode and map location for the genotyping(?) well.


## Commands to refresh the tracking database with data from iRODS ##

```
mysql -u $VRTRACK_RW_USER -hmcs10 -p$VRTRACK_PASSWORD vrtrack_hipsci_qc1_pilot < /lustre/scratch106/user/jm23/vrtrack_schema.sql
```

To update gtc files:
```
/software/vertres/bin-external/update_pipeline_hipsci/update_pipeline.pl -s $CONF/vrtrack_hipsci_qc1_pilot_studies -d vrtrack_hipsci_qc1_pilot -v -tax 9606 -sup -f gtc
```

To update idat files:
```
/software/vertres/bin-external/update_pipeline_hipsci/update_pipeline.pl -s $CONF/vrtrack_hipsci_qc1_pilot_studies -d vrtrack_hipsci_qc1_pilot -v -tax 9606 -sup -f idat
```

## Example metadata from a gtc file in iRODS ##

```
imeta ls -d /archive/GAPI/gen/infinium/f9/7a/42/9273354121_R01C02.gtc 
```

```
AVUs defined for dataObj /archive/GAPI/gen/infinium/f9/7a/42/9273354121_R01C02.gtc:
attribute: dcterms:identifier
value: hipscigt5466712
units: 
----
attribute: md5
value: f97a42b5a3d1712de8977b3896248323
units: 
----
attribute: study_title
value: HipSci_QC1_Pilot
units: 
----
attribute: sample
value: hipscigt5466712
units: 
----
attribute: dcterms:created
value: 2013-02-21T03:00:05
units: 
----
attribute: sample_common_name
value: Homo Sapien
units: 
----
attribute: dcterms:publisher
value: ldap://ldap.internal.sanger.ac.uk/ou=people,dc=sanger,dc=ac,dc=uk?title?sub?(uid=srpipe)
units: 
----
attribute: study_id
value: 2520
units: 
----
attribute: sample_consent
value: 1
units: 
----
attribute: beadchip
value: 9273354121
units: 
----
attribute: type
value: gtc
units: 
----
attribute: dcterms:creator
value: http://www.sanger.ac.uk
units: 
----
attribute: dcterms:title
value: coreex_hipscigt
units: 
----
attribute: sample_id
value: 1559364
units: 
----
attribute: dcterms:identifier
value: 271298_G01_hipscigt5466712
units: 
```
