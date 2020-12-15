package Koha::REST::V1::ZKSH_illrequests;

# Copyright 2019 LMSCloud GmbH
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

use Koha::DateUtils;
use C4::Context;
use Koha::Illrequest;

use Scalar::Util qw(blessed);
use Try::Tiny;

=head1 NAME

Koha::REST::V1::ZKSH_illrequests

=head1 API

=head2 Methods


=head3 add

Controller function that handles adding a new Koha::ZKSH_illrequests object

=cut

sub add {
#print STDERR "Koha::REST:V1:ZKSH_illrequests::add() START \n";
#print STDERR "Koha::REST:V1:ZKSH_illrequests::add() START _:" . $_, ":\n";
#print STDERR "Koha::REST:V1:ZKSH_illrequests::add() START Dumper _:" . Dumper($_), ":\n";
    
    my $argvalue = shift;
#print STDERR "Koha::REST:V1:ZKSH_illrequests::add() START Dumper argvalue:" . Dumper($argvalue), ":\n";

    my $c = $argvalue->openapi->valid_input or return;
#print STDERR "Koha::REST:V1:ZKSH_illrequests::add() START c:" . Dumper($c), ":\n";
#print STDERR "Koha::REST:V1:ZKSH_illrequests::add() START body:" . Dumper($c->validation->param('body')), ":\n";
    my $apiparams = $c->validation->param('body');

    return try {

        my ($responsecode, $responsetext) = &handleZKSHRequest($apiparams);
        return $c->render( status => $responsecode, openapi => { msg => $responsetext }  );
    }
    catch {
#print STDERR "Koha::REST:V1:ZKSH_illrequests::add() START catched _:" . Dumper($_), ":\n";
        unless ( blessed $_ && $_->can('rethrow') ) {
            return $c->render(
                status  => 500,
                openapi => { error => "Something went wrong, check Koha logs for details." }
            );
        }
        if ( $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
            return $c->render(
                status  => 409,
                openapi => { error => $_->error, conflict => $_->duplicate_id }
            );
        }
        else {
            return $c->render(
                status  => 500,
                openapi => { error => "Something went wrong, check Koha logs for details." }
            );
        }
    };
}


sub handleZKSHRequest {
    my $apiparams = shift;

    #my $dbh = C4::Context->dbh;    # XXXWH Empfehlung wei 06.08.2019: Wir sparen uns die ganze rollback-/commit-Chose bei RLV gebend / nehmend !
    ###$dbh->{AutoCommit} = 0;    # XXXWH Empfehlung wei 06.08.2019: Wir sparen uns die ganze rollback-/commit-Chose bei RLV gebend / nehmend !
    my $cmd = {};
    $cmd->{'req_valid'} = 0;

    my $respcode = '552';
    my $resptext = 'Unknown ZKSH ILL request';

#print STDERR "REST::V1::ZKSH_illrequests::handleZKSHRequest() Start; Dumper(apiparams):", Dumper($apiparams), ":\n";

    if ( $apiparams ) {
        # create an illrequests and some illrequestattributes records from the sent data using the Illbackend's methods
        my $illrequest;
        my $zksh_illbackend;
        my $args;
        my $backend_result;

        ###############################################################################################################
        # check if to handle an ILLZKSHA backend call   (RLV-Bestellung)
        ###############################################################################################################
        if ( $apiparams->{Art} && $apiparams->{Art} eq "RLV-Bestellung" ) {
            $illrequest = Koha::Illrequest->new();
            $zksh_illbackend = $illrequest->load_backend( "ILLZKSHA" ); # XXXWH Das ist immer noch $illrequest!

            $args->{stage} = 'commit';

            # not for fields of database tables
            $args->{'Art'} = $apiparams->{Art};
            $args->{'VerfuegbarkeitsSuche'} = $apiparams->{VerfuegbarkeitsSuche},    # string containig JSON availability search parameters

            # fields for table illrequests
            $args->{'branchcode'} = getBranchcodeFromOrderBranchIsil( C4::Context->preference("ILLDefaultBranch"), undef );
            $args->{'medium'} = "Book";    # XXXWH lt. Norbert hat man es immer mit 'Book' zu tun
            $args->{'orderid'} = $apiparams->{BestellID};

            # fields for table illrequestattributes
            $args->{attributes} = {
                'Bestellnummer' => $apiparams->{Bestellnummer},
                'ItemOrderExtid' => $apiparams->{ItemOrderExtid},
                'BZID' => $apiparams->{BZID},
                'Titel' => $apiparams->{Titel},
                'Verfasser' => $apiparams->{Verfasser},
                'ISBD' => $apiparams->{ISBD},
                'ISBN' => $apiparams->{ISBN},
                'ISNTyp' => $apiparams->{ISNTyp},
                'LeserName' => $apiparams->{LeserName} ? $apiparams->{LeserName} : '',
            };

            for my $attribute ( 'LeserNummer', 'LeserEmail', 'LeserTelNr', 'LeserAnmerkung', 'Serientitel', 'Medienart', 'Interessenkreis', 'URLzkshBase', 'URLzksh', 'BestelltAm', 'BestelltBeiSigel', 'BestelltBeiName', 'BestelltVonSigel', 'BestelltVonName', 'LieferungGeplant', 'Lieferweg', 'VerfuegbarkeitDatum', 'VerfuegbarkeitText' ) {
                if ( defined $apiparams->{$attribute} && length($apiparams->{$attribute}) ) {
                    $args->{attributes}->{$attribute} = $apiparams->{$attribute};
                };
            }

            # special fields for other tables
            $args->{specials} = {
            #    'Laufzettel' => $apiparams->{Laufzettel}    # will be stored in table message_queue    # stopped by wei 21.05.2019
            };

            $backend_result = $zksh_illbackend->backend_create($args);
#print STDERR "Koha::REST::V1::ZKSH_illrequests::handleZKSHRequest() after zksh_illbackend->backend_create() error:" . scalar $backend_result->{error} . 
#                                                                                        ": status:" . scalar $backend_result->{status} . 
#                                                                                       ": message:" . scalar $backend_result->{message} . 
#                                                                                        ": method:" . scalar $backend_result->{method} . 
#                                                                                         ": stage:" . scalar $backend_result->{stage} . 
#                                                                                          ": next:" . scalar $backend_result->{next} . ":\n";
        }

        ###############################################################################################################
        # check if to handle an ILLZKSHP backend call   (RLV-Bestellinfo, RLV-Lieferzusage)
        ###############################################################################################################
        if ( $apiparams->{Art} && $apiparams->{Art} eq "RLV-Bestellinfo" ) {
            $illrequest = Koha::Illrequest->new();
            $zksh_illbackend = $illrequest->load_backend( "ILLZKSHP" ); # XXXWH Das ist immer noch $illrequest!

            $args->{stage} = 'commit';

            # not for fields of database tables
            $args->{'Art'} = $apiparams->{Art};

            # fields for table illrequests
            $args->{'branchcode'} = getBranchcodeFromOrderBranchIsil( C4::Context->preference("ILLDefaultBranch"), $apiparams->{'BestelltVonSigel'} );
            $args->{'medium'} = "Book";    # XXXWH lt. Norbert hat man es immer mit 'Book' zu tun
            $args->{'orderid'} = $apiparams->{BestellID};

            # fields for table illrequestattributes
            $args->{attributes} = {
                'Bestellnummer' => $apiparams->{Bestellnummer},
                'ItemOrderExtid' => $apiparams->{ItemOrderExtid},
                'BZID' => $apiparams->{BZID},
                'Titel' => $apiparams->{Titel},
                'Verfasser' => $apiparams->{Verfasser},
                'ISBD' => $apiparams->{ISBD},
                'ISBN' => $apiparams->{ISBN},
                'ISNTyp' => $apiparams->{ISNTyp},
                'LeserName' => $apiparams->{LeserName} ? $apiparams->{LeserName} : '',
            };

            for my $attribute ( 'LeserNummer', 'LeserEmail', 'LeserTelNr', 'LeserAnmerkung', 'Serientitel', 'Medienart', 'Interessenkreis', 'VerlagJahrSonst', 'URLzkshBase', 'URLzksh', 'BestelltAm', 'BestelltBeiSigel', 'BestelltBeiName', 'LieferungGeplant', 'Lieferweg', 'VerfuegbarkeitDatum', 'VerfuegbarkeitText' ) {
                if ( defined $apiparams->{$attribute} && length($apiparams->{$attribute}) ) {
                    $args->{attributes}->{$attribute} = $apiparams->{$attribute};
                };
            }

            $backend_result = $zksh_illbackend->backend_create($args);
#print STDERR "REST::V1::ZKSH_illrequests::handleZKSHRequest() after zksh_illbackend->backend_create() error:" . scalar $backend_result->{error} . 
#                                                                                        ": status:" . scalar $backend_result->{status} . 
#                                                                                       ": message:" . scalar $backend_result->{message} . 
#                                                                                        ": method:" . scalar $backend_result->{method} . 
#                                                                                         ": stage:" . scalar $backend_result->{stage} . 
#                                                                                          ": next:" . scalar $backend_result->{next} . ":\n";
        } elsif ( $apiparams->{Art} && $apiparams->{Art} eq "RLV-Lieferzusage" ) {
            $illrequest = Koha::Illrequest->new();
            $zksh_illbackend = $illrequest->load_backend( "ILLZKSHP" ); # XXXWH Das ist immer noch $illrequest!

            $args->{stage} = 'commit';

            # not for fields of database tables
            $args->{'Art'} = $apiparams->{Art};

            # fields for table illrequests
            $args->{'orderid'} = $apiparams->{BestellID};

            # fields for table illrequestattributes
            for my $attribute ( 'Bemerkung', 'BestelltBeiSigel', 'BestelltBeiName', 'LieferungGeplant', 'Lieferweg', 'VerfuegbarkeitDatum', 'VerfuegbarkeitText' ) {
                if ( defined $apiparams->{$attribute} && length($apiparams->{$attribute}) ) {
                    $args->{attributes}->{$attribute} = $apiparams->{$attribute};
                };
            }

            #$backend_result = $zksh_illbackend->backend_confirm($args);
            $backend_result = $zksh_illbackend->_backend_capability( "confirmed", { request => $zksh_illbackend, other => $args } );
#print STDERR "REST::V1::ZKSH_illrequests::handleZKSHRequest() after zksh_illbackend->backend_confirmed() error:" . scalar $backend_result->{error} . 
#                                                                                        ": status:" . scalar $backend_result->{status} . 
#                                                                                       ": message:" . scalar $backend_result->{message} . 
#                                                                                        ": method:" . scalar $backend_result->{method} . 
#                                                                                         ": stage:" . scalar $backend_result->{stage} . 
#                                                                                          ": next:" . scalar $backend_result->{next} . ":\n";
        } elsif ( $apiparams->{Art} && $apiparams->{Art} eq "RLV-Lieferablehnung" ) {
            $illrequest = Koha::Illrequest->new();
            $zksh_illbackend = $illrequest->load_backend( "ILLZKSHP" ); # XXXWH Das ist immer noch $illrequest!

            $args->{stage} = 'commit';

            # not for fields of database tables
            $args->{'Art'} = $apiparams->{Art};

            # fields for table illrequests
            $args->{'orderid'} = $apiparams->{BestellID};
            $backend_result = $zksh_illbackend->_backend_capability( "erase", { request => $zksh_illbackend, other => $args } );
#print STDERR "REST::V1::ZKSH_illrequests::handleZKSHRequest() after zksh_illbackend->backend_erase() error:" . scalar $backend_result->{error} . 
#                                                                                        ": status:" . scalar $backend_result->{status} . 
#                                                                                       ": message:" . scalar $backend_result->{message} . 
#                                                                                        ": method:" . scalar $backend_result->{method} . 
#                                                                                         ": stage:" . scalar $backend_result->{stage} . 
#                                                                                          ": next:" . scalar $backend_result->{next} . ":\n";
        }

        if ( $backend_result->{error} ne '0' || 
             !defined $backend_result->{value} || 
             !defined $backend_result->{value}->{request} || 
             !$backend_result->{value}->{request}->illrequest_id() ) {
            ###$dbh->rollback;    # XXXWH Empfehlung wei 06.08.2019: Wir sparen uns die ganze rollback-/commit-Chose bei RLV gebend / nehmend !
            $cmd->{'req_valid'} = 0;
            if ( $backend_result->{status} eq "invalid_borrower" ) {
	            $cmd->{'err_type'} = 'PATRON_NOT_FOUND';
                if ( $apiparams->{Art} eq "RLV-Bestellung" ) {
	                $cmd->{'err_text'} = "No ordering library found searching for Sigel '" . scalar $apiparams->{BestelltVonSigel} . "'.";
                } else {
	                $cmd->{'err_text'} = "No patron found searching for name '" . scalar $apiparams->{LeserName} . "' or cardnumber '" . scalar $apiparams->{LeserNummer} . "'.";
                }
            } elsif ( $backend_result->{status} eq "illrequest_not_found" ) {
	            $cmd->{'err_type'} = 'ILLREQUEST_NOT_FOUND';
                $cmd->{'err_text'} = "No ILL request found searching for orderid '" . scalar $apiparams->{BestellID} . "'.";
            } else {
                $cmd->{'err_type'} = 'ILLREQUEST_NOT_CREATED';
                if ( $apiparams->{Art} eq "RLV-Bestellung" ) {
                    $cmd->{'err_text'} = "The Koha illrequest for the title with BZ-ID '" . scalar $apiparams->{BZID} . "' or ISBN '" . scalar $apiparams->{ISBN} . "' could not be created. (" . scalar $backend_result->{status} . ' ' . scalar $backend_result->{message} . ")";
                } else {
                    $cmd->{'err_text'} = "The Koha illrequest for the title '" . scalar $apiparams->{Titel} . "' could not be created. (" . scalar $backend_result->{status} . ' ' . scalar $backend_result->{message} . ")";
                }
            }
        } else {
            $cmd->{'req_valid'} = 1;
            $cmd->{'rsp_para'}->[0] = [ 0, 'PFLNummer', $backend_result->{value}->{request}->illrequest_id() ];
            $cmd->{'rsp_para'}->[1] = [ 0, 'OKMsg', 'ILL request successfully inserted.' ];

            ###$dbh->commit();    # XXXWH Empfehlung wei 06.08.2019: Wir sparen uns die ganze rollback-/commit-Chose bei RLV gebend / nehmend !
            #$dbh->{AutoCommit} = 1;    # XXXWH Schlimmer Fehler, das gehört HINTER den else-Block! sonst Auswirkung bei plack-Betrieb: nach einem rollback erfolgte Datenbankänderungen dieses worker-Prozesses bleiben UNCOMMITTED !!!
        }
        ###$dbh->{AutoCommit} = 1;    # XXXWH Empfehlung wei 06.08.2019: Wir sparen uns die ganze rollback-/commit-Chose bei RLV gebend / nehmend !

        if ( $cmd->{'req_valid'} == 1 ) {
            $respcode = '201';
            $resptext = 'OK';
        } else {
            $respcode = '500';
            $resptext = $cmd->{'err_type'};
            if ( $cmd->{'err_text'} ne '' ) {
                $resptext .= ' '.$cmd->{'err_text'};
            }
        }
    }

	return ($respcode,$resptext);
}

sub getBranchcodeFromOrderBranchIsil {
    my ( $iLLDefaultBranchPreference, $orderbranchIsil ) = @_;
    my $retBranchcode = '';

    if ( $iLLDefaultBranchPreference ) {    # e.g. for Norderstedt: '1|672:1|673:3|674:2|676:4' or more compact: '1|673:3|674:2|676:4'
        my @isilBranchcodeAssignments = split( /\|/, $iLLDefaultBranchPreference );
        if ( @isilBranchcodeAssignments ) {
            if ( defined($isilBranchcodeAssignments[0]) ) {
                $retBranchcode = $isilBranchcodeAssignments[0];
            }
            foreach my $isilBranchcodeAssignment ( @isilBranchcodeAssignments ) {
                my ( $isil, $branchcode ) = split( /:/, $isilBranchcodeAssignment );
                #if ( $isil && $branchcode ) {
                if ( $branchcode ) {
                    if ( $isil eq $orderbranchIsil ) {
                        $retBranchcode = $branchcode;
                        last;
                    }
                }
            }
        }
    }

    return $retBranchcode;
}

1;
