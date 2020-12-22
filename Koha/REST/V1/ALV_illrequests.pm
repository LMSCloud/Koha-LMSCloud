package Koha::REST::V1::ALV_illrequests;

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

Koha::REST::V1::ALV_illrequests

=head1 API

=head2 Methods


=head3 add

Controller function that handles adding a new Koha::ALV_illrequests object

=cut

sub add {
print STDERR "Koha::REST:V1:ALV_illrequests::add() START \n";
print STDERR "Koha::REST:V1:ALV_illrequests::add() START _:" . $_, ":\n";
print STDERR "Koha::REST:V1:ALV_illrequests::add() START Dumper _:" . Dumper($_), ":\n";
    
    my $argvalue = shift;
print STDERR "Koha::REST:V1:ALV_illrequests::add() START Dumper argvalue:" . Dumper($argvalue), ":\n";

    my $c = $argvalue->openapi->valid_input or return;
print STDERR "Koha::REST:V1:ALV_illrequests::add() START c:" . Dumper($c), ":\n";
print STDERR "Koha::REST:V1:ALV_illrequests::add() START body:" . Dumper($c->validation->param('body')), ":\n";
    my $apiparams = $c->validation->param('body');

    return try {

        my ($responsecode, $responsetext) = &handleALVRequest($apiparams);
        return $c->render( status => $responsecode, openapi => { msg => $responsetext }  );
    }
    catch {
print STDERR "Koha::REST:V1:ALV_illrequests::add() START catched _:" . Dumper($_), ":\n";
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


sub handleALVRequest {
    my $apiparams = shift;
    my $modelparams = {};

    my $cmd = {};
    $cmd->{'req_valid'} = 0;

    my $respcode = '552';
    my $resptext = 'Unknown ALV ILL request';

print STDERR "REST::V1::ALV_illrequests::handleZKSHRequest() Start; Dumper(apiparams):", Dumper($apiparams), ":\n";
    foreach my $apiparam ( keys %{ $Koha::REST::V1::ALV_illrequests::to_model_mapping } ) {
        my $modelparam = $Koha::REST::V1::ALV_illrequests::to_model_mapping->{$apiparam};
        $modelparams->{$modelparam} = $apiparams->{$apiparam};
    }
print STDERR "REST::V1::ALV_illrequests::handleZKSHRequest() Start; Dumper(modelparams):", Dumper($modelparams), ":\n";

    if ( $modelparams ) {
        # create an illrequests and some illrequestattributes records from the sent data using the Illbackend's methods
        my $illrequest;
        my $alv_illbackend;
        my $args;
        my $backend_result;

        ###############################################################################################################
        # handle an ILLALV backend call   (ALV-Bestellung)
        ###############################################################################################################
        $illrequest = Koha::Illrequest->new();
        $alv_illbackend = $illrequest->load_backend( "ILLALV" ); # XXXWH Das ist immer noch $illrequest!

        $args->{stage} = 'commit';

        # fields for table illrequests
        my @illDefaultBranch =split( /\|/, C4::Context->preference("ILLDefaultBranch") );
        $args->{'branchcode'} = $illDefaultBranch[0];
        if ( $modelparams->{Auftragsart} eq 'Zeitschriften-/Aufsatzbestellung' ) {
            $args->{'medium'} = "Article";
        } else {
            $args->{'medium'} = "Book";
        }

        # fields for table illrequestattributes
        $args->{attributes} = {
            'Titel' => $modelparams->{Titel},
            'Verfasser' => $modelparams->{Verfasser},
            'ISBN' => $modelparams->{ISBN},
            'LeserName' => $modelparams->{LeserName} ? $modelparams->{LeserName} : '',
            'BestelltVonSigel' => $modelparams->{BestelltVonSigel} ? $modelparams->{BestelltVonSigel} : '',
            'DS_Zustimmung' => $modelparams->{DS_Zustimmung} ? $modelparams->{DS_Zustimmung} : 'N',
            'Nichtkomm_Zweck' => $modelparams->{Nichtkomm_Zweck} ? $modelparams->{Nichtkomm_Zweck} : 'N',
        };

        for my $attribute (
            'Alternativer_Titel',
            'Andere_Auflage',
            'BenoetigtBis',
            'BestelltAm',
            'BestelltVonEmail',
            'BestelltVonName',
            'Digitales_Medium',
            'ILV_erlaubt',
            'Kopierkosten',
            'LeserEmail',
            'LeserAdresse',
            'LeserAnmerkung',
            'LeserNummer',
            'TiteltrefferZKSH',
            'VerlagJahrSonst'
        ) {
            if ( defined $modelparams->{$attribute} && length($modelparams->{$attribute}) ) {
                $args->{attributes}->{$attribute} = $modelparams->{$attribute};
            };
        }

        $backend_result = $alv_illbackend->backend_create($args);
print STDERR "Koha::REST::V1::ALV_illrequests::handleZKSHRequest() after alv_illbackend->backend_create() error:" . scalar $backend_result->{error} . 
                                                                                        ": status:" . scalar $backend_result->{status} . 
                                                                                       ": message:" . scalar $backend_result->{message} . 
                                                                                        ": method:" . scalar $backend_result->{method} . 
                                                                                         ": stage:" . scalar $backend_result->{stage} . 
                                                                                          ": next:" . scalar $backend_result->{next} . ":\n";

        if ( $backend_result->{error} ne '0' || 
             !defined $backend_result->{value} || 
             !defined $backend_result->{value}->{request} || 
             !$backend_result->{value}->{request}->illrequest_id() ) {
            $cmd->{'req_valid'} = 0;
            if ( $backend_result->{status} eq "invalid_borrower" ) {
	            $cmd->{'err_type'} = 'PATRON_NOT_FOUND';
                $cmd->{'err_text'} = "No ordering library found searching for ISIL '" . scalar $modelparams->{BestelltVonSigel} . "'.";
            } else {
                $cmd->{'err_type'} = 'ILLREQUEST_NOT_CREATED';
                $cmd->{'err_text'} = "The Koha illrequest for the title '" . scalar $modelparams->{Titel} . "' or ISBN '" . scalar $modelparams->{ISBN} . "' could not be created. (" . scalar $backend_result->{status} . ' ' . scalar $backend_result->{message} . ")";
            }
        } else {
            $cmd->{'req_valid'} = 1;
            $cmd->{'rsp_para'}->[0] = [ 0, 'PFLNummer', $backend_result->{value}->{request}->illrequest_id() ];
            $cmd->{'rsp_para'}->[1] = [ 0, 'OKMsg', 'ILL request successfully inserted.' ];
        }

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

=head3 $to_model_mapping

=cut

our $to_model_mapping = {
    additionalInfo => 'VerlagJahrSonst',
    altIssues => 'Andere_Auflage',
    altTitle => 'Alternativer_Titel',
    copyCosts => 'Kopierkosten',
    digitalMedium => 'Digitales_Medium',
    intlILL => 'ILV_erlaubt',
    mediumAuthor => 'Verfasser',
    mediumIsbn => 'ISBN',
    mediumTitle => 'Titel',
    orderDate => 'BestelltAm',
    orderLibEmail => 'BestelltVonEmail',
    orderLibIsil => 'BestelltVonSigel',
    orderLibName => 'BestelltVonName',
    orderType => 'Auftragsart',
    patronAddress => 'LeserAdresse',
    patronEmail => 'LeserEmail',
    patronName => 'LeserName',
    patronNumber => 'LeserNummer',
    patronRemark => 'LeserAnmerkung',
    requiredDate => 'BenoetigtBis',
    titleHitZKSH => 'TiteltrefferZKSH',
    dataPrivacyAgreed => 'DS_Zustimmung',
    nonCommercial => 'Nichtkomm_Zweck'
};

1;
