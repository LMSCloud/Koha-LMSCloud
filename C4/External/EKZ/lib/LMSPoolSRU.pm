package LMSPoolSRU;

# Copyright 2017 (C) LMSCLoud GmbH
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

use strict;
use warnings;

use utf8;
use URI::Escape;
use LWP::UserAgent;
use XML::LibXML;
use Business::ISBN;

use MARC::Record;

our $VERSION = '0.01';

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

use constant LMSPOOLURL => 'http://127.0.0.1:4900/biblios?version=1.1&operation=searchRetrieve&query=%QUERY%&maximumRecords=1&recordSchema=marcxml';

BEGIN {
    require Exporter;
    $VERSION = 1.00.00.000;
    @ISA = qw(Exporter);
    @EXPORT = qw(LMSPOOLURL);
}

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	$self->{'url'} = LMSPOOLURL;
	
	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	$ua->env_proxy;

	$self->{'ua'} = $ua;

	return $self;
}

sub getbyId {
	my $self = shift;
	my $idlist   = shift;
	
	my $result = { 
			'count'        => 0, 
			'records'      => []
		};
	
	my $chk = 0;
	my $qstring = '';
	foreach my $id (@$idlist) {
		$chk++;
		$qstring .= ' or ' if ( $qstring ne '');
		$qstring .= 'rec.cn="' . $id . '"';
	}
	
	if ( $chk>0 ) {
		my $url = $self->{'url'};
		
		$url =~ s/%QUERY%/uri_escape_utf8(${qstring})/eg;
		
		$self->doQuery($url,$result);
	}
	return $result;
}

sub getbyISBN {
	my $self = shift;
	my $isbnlist   = shift;
	my %searchedisbn = ();
	
	my $result = { 
			'count'        => 0, 
			'records'      => []
		};
	
	foreach my $isbn (@$isbnlist) {
		
		my $url = $self->{'url'};
		my $isbnlong = undef;
		my $isbnshort = undef;
		my $isbnlongdash = undef;
		my $isbnshortdash = undef;
		
		eval {
			my $isbn13 = Business::ISBN->new($isbn);
			if ( defined($isbn13) ) {
				$isbnlong = $isbn13->as_string([]);
				$isbnlongdash = $isbn13->as_string();
				$isbnshort = $isbn13->as_isbn10->as_string([]);
				$isbnshortdash = $isbn13->as_isbn10->as_string();
			}
		};
		
		my $chk = 0;
		my $qstring = '';
		if ( defined($isbnlong) && (! exists($searchedisbn{$isbnlong}) ) ) {
			$chk++;
			$searchedisbn{$isbnlong} = 1;
			$qstring .= ' or ' if ( $qstring ne '');
			$qstring .= 'dc.isbn="'.$isbnlong.'"';
			if ( defined($isbnlongdash) ) { 
				$qstring .= ' or ' if ( $qstring ne '');
				$qstring .= 'dc.isbn="'.$isbnlongdash.'"';
			}
		}
		if ( defined($isbnshort) && (! exists($searchedisbn{$isbnshort}) ) ) {
			$chk++;
			$searchedisbn{$isbnshort} = 1;
			$qstring .= ' or ' if ( $qstring ne '');
			$qstring .= 'dc.isbn="'.$isbnshort.'"';
			if ( defined($isbnshortdash) ) { 
				$qstring .= ' or ' if ( $qstring ne '');
				$qstring .= 'dc.isbn="'.$isbnshortdash.'"';
			}
		}
			
		if ( $chk == 0 ) {
			next;
		}	
		
		$url =~ s/%QUERY%/uri_escape_utf8(${qstring})/eg;
		
		$self->doQuery($url,$result);
	}
	return $result;
}

# search strings from $idlist in MARC fields 20, 22, 24 (ISBN, ISSN, ISMN and EAN)
sub getbyIdentifierStandard {
	my $self = shift;
	my $idlist   = shift;
	
	my $result = { 
			'count'        => 0, 
			'records'      => []
		};
	
	my $chk = 0;
	my $qstring = '';
	foreach my $id (@$idlist) {
		$chk++;
		$qstring .= ' or ' if ( $qstring ne '');
		$qstring .= 'dc.identifier="' . $id . '"';
	}
	
	if ( $chk>0 ) {
		my $url = $self->{'url'};
		
		$url =~ s/%QUERY%/uri_escape_utf8(${qstring})/eg;
		
		$self->doQuery($url,$result);
	}
	return $result;
}

sub doQuery {
	my $self = shift;
	my $url = shift;
	my $result = shift;
	
	my $response = $self->{'ua'}->get($url);

	if ($response->is_success) {
		my $parser = XML::LibXML->new;
		my $dom = $parser->parse_string($response->content);

		my $root = $dom->documentElement();
		my $nsURI = $root->namespaceURI();
		$root->setNamespace($nsURI, 'x');    
		my $res = $root->findnodes('x:records/x:record/x:recordData');

		foreach my $record ( $res->get_nodelist() ) {
			foreach my $child ( $record->childNodes() ) {
				if ( $child->nodeName eq 'record' ) {
					$result->{'count'} += 1;
					push @{$result->{'records'}}, MARC::Record->new_from_xml( $child->toString(), "UTF-8", "MARC21" );
				}
			}
		}
	}
	
	return $result;
}

1;
