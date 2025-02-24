package C4::Divibib::NCIPService;

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

use strict;
use warnings;

use Carp;

use utf8;
use Data::Dumper;

use LWP::UserAgent;
use Clone qw(clone);
use DateTime;
use Koha::DateUtils qw( dt_from_string );
use MARC::File::XML;
use MARC::Record;
use C4::Context;
use C4::Search;
use C4::Divibib::NCIP::LookupUser;
use C4::Divibib::NCIP::LookupItem;
use C4::Divibib::NCIP::RequestItem;

use Koha::SearchEngine::Search;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

use constant DIVIBIBAGENCYID => 'DE-Wi27';
use constant DIVIBIBITEMSOURCE => 'onleihe';
use constant DIVIBIBISSUEBRANCHCODE => 'eBib';

BEGIN {
    require Exporter;
    $VERSION = 2.0;
    @ISA = qw(Exporter);
    @EXPORT = qw(DIVIBIBAGENCYID);
    @EXPORT_OK = qw(DIVIBIBAGENCYID);
}

=head1 NAME

C4::Divibib::NCIP::Command::LookupUser - Command LookupUser of the Divibib NCIP interface.

=head1 SYNOPSIS

LookupUser - Usre Login and forwards to a URL address

=head1 DESCRIPTION

The module implements the LookupUser command of the Divibib NCIP interface. 
It takes the borrower number or barcode and returns a URL to an authenticated user session 
of the divibib interface.

The command delivers the XML request data and parses the XML repsonse data.

=head1 FUNCTIONS

=cut

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    
    my $url = "https://ncip.onleihe.de/ncip/service/";
    if ( C4::Context->preference("DivibibVersion") && 
            C4::Context->preference("DivibibVersion") =~ /^([1-9])/ ) 
    {
        $url = "https://api.onleihe.de/ncip/" if ( $1 >= 3 );
    }
    if ( C4::Context->preference("DivibibNCIPServiceURL") ) {
        $url = C4::Context->preference("DivibibNCIPServiceURL");
    }
    
    $self->{'url'} = $url;
    
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
    
    $self->{'ua'} = $ua;

    return $self;
}

sub lookupUser {
    my $self = shift;
    my ($userId,$withAccount) = @_;
    
    $userId =~ s/^\s+|\s+$//g;
    
    if ( $userId ne '' ) {
        my $cmd = C4::Divibib::NCIP::LookupUser->new($userId,$withAccount);
        $self->_fetch_divibib_data($cmd);
        return ($cmd->getResponse(),$cmd->getResponseOk(),$cmd->getResponseError(),$cmd->getResponseErrorCode());
    }
    return (undef,0,"Incomplete request data. User id not provided.",undef);
}

sub lookupItem {
    my $self = shift;
    my ($itemId) = @_;
    
    $itemId =~ s/^\s+|\s+$//g;
    
    if ( $itemId ne '' ) {
        my $cmd = C4::Divibib::NCIP::LookupItem->new($itemId);
        $self->_fetch_divibib_data($cmd);
        return ($cmd->getResponse(),$cmd->getResponseOk(),$cmd->getResponseError(),$cmd->getResponseErrorCode());
    }
    return (undef,0,"Incomplete request data. Item id not provided.",undef);
}

sub requestItem {
    my $self = shift;
    my ($userId,$itemId,$doLoan) = @_;
    
    $itemId =~ s/^\s+|\s+$//g;
    $userId =~ s/^\s+|\s+$//g;
    
    if ( $itemId ne '' && $userId ne '' ) {
        my $cmd = C4::Divibib::NCIP::RequestItem->new($userId, $itemId, $doLoan);
        $self->_fetch_divibib_data($cmd);
        return ($cmd->getResponse(),$cmd->getResponseOk(),$cmd->getResponseError(),$cmd->getResponseErrorCode());
    }
    return (undef,0,"Incomplete request data. Item order user id not provided: ItemId='$itemId' userId='$userId'",undef);
}

sub setItemTypeIconAndDescription {
    my ($itemType,$item) = @_;
    
    if ( $itemType eq 'ebook') {
        $item->{'imageurl'} = 'bridge/e_book.gif';
        $item->{'description'} = 'Elektronisches Buch zum Download'
    }
    elsif ( $itemType eq 'eaudio') {
        $item->{'imageurl'} = 'bridge/digital_audio.gif';
        $item->{'description'} = 'Hörbuch zum Download';
    }
    elsif ( $itemType eq 'emusik') {
        $item->{'imageurl'} = 'bridge/e_music.gif';
        $item->{'description'} = 'Song zum Download';
    }
    elsif ( $itemType eq 'epapier') {
        $item->{'imageurl'} = 'bridge/e_journal.gif';
        $item->{'description'} = 'Elektronische Zeitschrift zum Download';
    }
    elsif ( $itemType eq 'evideo') {
        $item->{'imageurl'} = 'bridge/e_video.gif';
        $item->{'description'} = 'Video zum Download';
    }
}

sub getItemInformation {
    my $self = shift;
    my ($biblionumber,$itemId,$userId) = @_;
    
    my ($divibibItem,$responseOk,$errMessage,$errCode) = $self->lookupItem($itemId, 1);
    
    if ( $responseOk && $divibibItem->{'ItemId'} ) {
        my $item = {};
        my $today = dt_from_string;

        if ( $divibibItem->{'Available'} == 0 && 
             $divibibItem->{'Reservable'} == 1 && 
             $divibibItem->{'DateAvailable'} =~ /^(\d\d\d\d-\d\d-\d\d)/ ) 
        {
            $item->{'date_due'} =  dt_from_string("$1", 'sql');
            $item->{'date_due_sql'}  = "$1 00:00:00";
            $item->{'datedue'}   = "$1 00:00:00";
        }
        if ( exists($item->{date_due}) && DateTime->compare($item->{date_due}, $today) == -1 ) {
            $item->{'overdue'} = 1;
        }
                
        $item->{'itemnumber'} = "(".DIVIBIBAGENCYID.")" . $divibibItem->{'ItemId'};
        
        $item->{'itemSource'} = DIVIBIBITEMSOURCE;
        $item->{'itemtype'} = $divibibItem->{'ItemType'};
        
        setItemTypeIconAndDescription($item->{'itemtype'}, $item);

        $item->{'barcode'} = '';
        $item->{'this_branch'} = 1;
        
        $item->{'onleihe'} = 1;
        $item->{'available'} = $divibibItem->{'Available'};
        $item->{'reservable'} = $divibibItem->{'Reservable'};
        $item->{'itemId'} = $divibibItem->{'ItemId'};

        #$item->{'holding_branch_opac_info'} = 'Elektronisches Material';
        $item->{'branchname'} = 'Onleihe';
        
        #use Data::Dumper;
        #open (my $fh, ">", "/tmp/Dumper");
        #print $fh "_fetch_divibib_data", Dumper($divibibItem);
        #print $fh "_fetch_divibib_data", Dumper($item);
        
        return [$item];
    }
    return undef;
}

sub getPendingIssues {
    my $self = shift;
    my ($userId) = @_;
    my ($accountData,$responseOk,$errMessage,$errCode) = $self->lookupUser($userId, 1);
    my $divibibIDs = [];
    my $result = [];
    
    if ( $responseOk && $accountData->{'LoanedItems'} ) {
        
   	my $loanedDivibibItems = $accountData->{'LoanedItems'};

    unless (@$loanedDivibibItems ) { # return a ref_to_array
        return \@$divibibIDs; # to not cause surprise to caller
    }
    
    # Query local biblio record IDs of the Divibib entries
    my $query = '(';
    for (my $i = 0; $i < @$loanedDivibibItems; $i++) {
        if ($i > 0) {
            $query .= " OR "
        }
        $query .= 'cn="' . $loanedDivibibItems->[$i]->{'ItemId'} . '"';
    }
    $query .= ') AND cna="' . DIVIBIBAGENCYID . '"';

    my $searcher = Koha::SearchEngine::Search->new({index => 'biblios'});
    my ( $error, $marcresults, $total_hits ) = $searcher->simple_search_compat($query, 0, 1000);

    if (defined $error) {
        warn "error: ".$error;
    }
    
    my @recordnumbers;
    my %recordToDivibibId;
    for my $r ( @{$marcresults} ) {
        my $marcrecord = C4::Search::new_record_from_zebra( 'biblioserver', $r);
        push @recordnumbers, $marcrecord->subfield('999','c');      
        $recordToDivibibId{$marcrecord->subfield('999','c')} = $marcrecord->field('001')->data();
    }
	
	$query =
		"SELECT biblio.*,
		    biblioitems.volume,
		    biblioitems.number,
		    biblioitems.itemtype,
		    biblioitems.isbn,
		    biblioitems.issn,
		    biblioitems.publicationyear,
		    biblioitems.publishercode,
		    biblioitems.volumedate,
		    biblioitems.volumedesc,
		    biblioitems.lccn,
		    biblioitems.url
		FROM biblio
		    LEFT JOIN biblioitems ON biblio.biblionumber = biblioitems.biblioitemnumber
		WHERE
		    biblio.biblionumber in ('" . join("','",@recordnumbers) . "')";

	my $sth = C4::Context->dbh->prepare($query);
	$sth->execute();
	my $data = $sth->fetchall_arrayref({});
        
	my $today = dt_from_string;

        foreach my $divibibItem( @{$loanedDivibibItems} ) {
            foreach my $biblioItem (@{$data}) {
                if ( $divibibItem->{'ItemId'} eq $recordToDivibibId{$biblioItem->{'biblionumber'}} ) {
                    my $divibibIssue = clone($biblioItem);

                    if ( $divibibItem->{'DatePlaced'} =~ /^(\d\d\d\d-\d\d-\d\d)T(\d\d:\d\d:\d\d)/ ) {
                        $divibibIssue->{issuedate} =  dt_from_string("$1 $2", 'sql');
                    }
                    if ( $divibibItem->{'DateDue'} =~ /^(\d\d\d\d-\d\d-\d\d)T(\d\d:\d\d:\d\d)/ ) {
                        $divibibIssue->{date_due} =  dt_from_string("$1 $2", 'sql');
                        $divibibIssue->{date_due_sql}  = "$1 $2";
                    }
                    if ( DateTime->compare($divibibIssue->{date_due}, $today) == -1 ) {
                        $divibibIssue->{overdue} = 1;
                    }
                
                   $divibibIssue->{itemnumber} = "(".DIVIBIBAGENCYID.")" . $divibibItem->{'ItemId'};
                   $divibibIssue->{itemSource} = DIVIBIBITEMSOURCE;
                   $divibibIssue->{itemtype} = $divibibItem->{'BibliographicDescription'}->{'MediumType'};
                
                   setItemTypeIconAndDescription(lc($divibibIssue->{itemtype}), $divibibIssue);

                   $divibibIssue->{barcode} = $divibibIssue->{itemtype};
                   $divibibIssue->{branchcode} = DIVIBIBISSUEBRANCHCODE;
                   
                   $divibibIssue->{renewal_imposssible} = 1;
                   
                   push @$result, $divibibIssue;
                   last;
                }
            }
        }
    }
    return $result;
}



sub _fetch_divibib_data {
    my $self = shift;
    
    my ($cmd) = @_;

    my $response = $self->{'ua'}->post($self->{'url'}, Content_Type => 'application/xml', Accept => 'application/xml', Content => $cmd->getXML());
    
    if ( $response->is_success ) {
        $cmd->parseResponse($response->content);
        
        if (! $cmd->getResponseOk() ) {
            carp "C4::Divibib::NCIPService unsuccessful command: " . $cmd->getXML() . "\nResult: " . $response->content;
        }
    }
    else {
        carp "C4::Divibib::NCIPService error calling command: " . $cmd->getXML() . "\nResult: " . $response->error_as_HTML . "\nResponse-content: " . $response->content;
        $cmd->responseError($response->error_as_HTML, $response->code);
    }
    
    #use Data::Dumper;
    #open (my $fh, ">", "/tmp/Dumper");
    #print $fh "_fetch_divibib_data", Dumper($cmd);
    #print $fh "_fetch_divibib_data", Dumper($response);
      
    warn "could not retrieve ".$self->{'url'} unless ($response->content && $response->is_success && $cmd->getResponseOk());
    return $response;
}

1;
