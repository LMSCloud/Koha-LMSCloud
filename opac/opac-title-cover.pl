#!/usr/bin/perl

# Copyright 2016 LMSCloud GmbH
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

=head1 DESCRIPTION

This script is used to return availability information of digital material 
of the German eBook/eMedia vendor Divibib via ajax json response. Since retrieving
availability information from the Divivbib Onleihe may take some seconds,
we retrieve this information for each title of a result separatly,

=cut

use strict;
use warnings;
use utf8;

use CGI qw ( -utf8 );
use CGI::Cookie;  # need to check cookies before having CGI parse the POST request

use MARC::File::XML;
use MARC::File::USMARC;
use MARC::Record;

use C4::Context;
use C4::Debug;
use C4::Output qw(:html :ajax pagination_bar);
use C4::Search;
use C4::Charset;
use C4::Koha;
use URI::Escape;


use JSON;

my $is_ajax = 1;
my $query = CGI->new();


my @js_reply = ();
my $json_reply;
    
my @bibids = ();

if ( $query && $query->param('bibid') ) {
    foreach my $splitId( split /(\s+|,)/, $query->param('bibid')  ) {
        if ( $splitId =~ /^\d+$/ ) {
            push @bibids, $splitId;
        }
    }
}

if ( @bibids > 0 ) {
    my $dbh            = C4::Context->dbh;
    my $sth            = $dbh->prepare("SELECT i.biblioitemnumber AS biblioitemnumber, i.biblionumber AS biblionumber, m.metadata AS metadata, b.frameworkcode AS frameworkcode FROM biblioitems i, biblio b, biblio_metadata m WHERE m.biblionumber = i.biblionumber AND i.biblionumber = b.biblionumber AND i.biblionumber IN (" . join(",",@bibids) . ')');
    my $count          = 0;

    $sth->execute();
    while ( my $data = $sth->fetchrow_hashref ) {
        
        my $biblionumber = $data->{'biblionumber'};
        my $biblioitemnumber = $data->{'biblioitemnumber'};
        my $marcxml = StripNonXmlChars( $data->{'metadata'} );
        my $frameworkcode = $data->{'frameworkcode'};
        
        MARC::File::XML->default_record_format( C4::Context->preference('marcflavour') );
        my $record = MARC::Record->new();

        if ($marcxml) {
            my $Koharecord = eval {
                MARC::Record::new_from_xml( $marcxml, "utf8", C4::Context->preference('marcflavour') );
            };
            if ($@) { warn " problem with :$biblionumber : $@ \n$marcxml";  next }
        
            my $field = $Koharecord->field('245');
            my $titleblock = "";
            my $title = "";
            my $author = "";
        
            if ( $field ) {
                $title = $field->subfield('a');
                my $subtitle = $field->subfield('b');
                $author = $field->subfield('c');
		
                $titleblock = $title;
                
                if ( $subtitle ) {
                    $titleblock .= ': ' . $subtitle;
                }
                if ( $author ) {
                    $titleblock .= ' / ' . $author;
                }
                if ( $titleblock !~ /\.$/ ) {
                    $titleblock .= '.';
                }
            }
		
            $field = $Koharecord->field('250');
            if ( $field ) {
                my $edition = $field->subfield('a');
		
                if ( $edition ) {
                    $titleblock .= ' - ' . $edition;
                    if ( $titleblock !~ /\.$/ ) {
                        $titleblock .= '.';
                    } 
                }
            }
		
            $field = $Koharecord->field('260');
            if ( $field ) {
                my $location = $field->subfield('a');
                my $publisher = $field->subfield('b');
                my $year = $field->subfield('c');
		
                my $publisherblock = $location;
                    if ( $publisherblock && ( defined($publisher) || defined($year) )) {
                        $publisherblock .= ': ';
                    }
                    if ( $publisher ) {
                        $publisherblock .=  $publisher;
                    }
                    if ( $year ) {
                        if ( $publisherblock ne '' ) {
                            $publisherblock .= ', ';
                        }
                        $publisherblock .=  $year;
                    }
                    if ( $publisherblock ) {
                        $titleblock .= ' - ' . $publisherblock;
                        if ( $titleblock !~ /\.$/ ) {
                            $titleblock .= '.';
                        }
                    }
            }
            $title =~ s/[\x{0098}\x{009c}]//g;
            $author =~ s/[\x{0098}\x{009c}]//g;
            $titleblock =~ s/[\x{0098}\x{009c}]//g;
		
		
            my $identifier = '';
            $field = $Koharecord->field('020');
            if ( $field ) {
                my $isbn = $field->subfield('a');
                $identifier = $isbn;
            }
            $field = $Koharecord->field('024');
            if ( $field && $identifier eq '' ) {
                my $ean = $field->subfield('a');
                $identifier = $ean;
            }
		
            my $coverurl = '';
            foreach my $field ( $Koharecord->field('856') ) {
                if ( $field->subfield('q') && $field->subfield('q') =~ /^cover/ && $field->subfield('u') ) {
                    $coverurl = $field->subfield('u');
                    $coverurl =~ s#http:\/\/cover\.ekz\.de#https://cover.ekz.de#;
                    $coverurl =~ s#http:\/\/www\.onleihe\.de#https://www.onleihe.de#;
                    last;
                }
            }
            
            if ( $coverurl eq '' ) {
                $coverurl = 'https://cover.lmscloud.net/gencover?ti=' . uri_escape_utf8($title) .'&au=' . uri_escape_utf8($author) ;
            }

        
            push @js_reply, {
                            id             => $biblioitemnumber,
                            title          => $titleblock,
                            identifier     => $identifier,
                            coverurl       => $coverurl
                          };
        }
    }
}

$json_reply = JSON->new->utf8->encode( { titles => \@js_reply } );

output_ajax_with_http_headers( $query, $json_reply );
exit;

