#!/usr/bin/perl

#script to show suppliers and orders
#written by chris@katipo.co.nz 23/2/2000


# Copyright 2000-2002 Katipo Communications
# Copyright 2008-2009 BibLibre SARL
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

=head1 NAME

updatesupplier.pl

=head1 DESCRIPTION

this script allow to update or create (if id == 0)
a supplier. This script is called from acqui/supplier.pl.

=head1 CGI PARAMETERS

All informations regarding this supplier are listed on input parameter.
Here is the list :

supplier, id, company, company_postal, physical, company_phone,
physical, company_phone, company_fax, website, company_email, notes,
status, publishers_imprints, list_currency, gst, list_gst, invoice_gst,
discount, tax_rate, contact_name, contact_position, contact_phone,
contact_altphone, contact_fax, contact_email, contact_notes,
contact_claimacquisition, contact_claimissues, contact_acqprimary,
contact_serialsprimary.

=cut

use Modern::Perl;
use List::Util;
use C4::Context;
use C4::Auth;

use C4::Biblio;
use C4::Output;

use Koha::Acquisition::Bookseller::Contacts;
use Koha::Acquisition::Booksellers;
use CGI qw ( -utf8 );

my $input=new CGI;

checkauth( $input, 0, { acquisition => 'vendors_manage' }, 'intranet' );

#print $input->header();
my $booksellerid=$input->param('booksellerid');
#print startpage;
my %data;
$data{'id'}=$booksellerid;

$data{'name'}=$input->param('company');
$data{'postal'}=$input->param('company_postal');
my $address=$input->param('physical');
my @addresses=split('\n',$address);
$data{'address1'}=$addresses[0];
$data{'address2'}=$addresses[1];
$data{'address3'}=$addresses[2];
$data{'address4'}=$addresses[3];
$data{'phone'}=$input->param('company_phone');
$data{'accountnumber'}=$input->param('accountnumber');
$data{'fax'}=$input->param('company_fax');
$data{'url'}=$input->param('website');
# warn "".$data{'contnotes'};
$data{'notes'}=$input->param('notes');
$data{'active'}=$input->param('status');

$data{'listprice'}=$input->param('list_currency');
$data{'invoiceprice'}=$input->param('invoice_currency');
$data{'gstreg'}=$input->param('gst');
$data{'listincgst'}=$input->param('list_gst');
$data{'invoiceincgst'}=$input->param('invoice_gst');
#have to transform this into fraction so it's easier to use
$data{'tax_rate'} = $input->param('tax_rate');
$data{'discount'} = $input->param('discount');
$data{deliverytime} = $input->param('deliverytime');
$data{'active'}=$input->param('status');
my @contacts;
my %contact_info;

foreach (qw(id name position phone altphone fax email notes orderacquisition claimacquisition claimissues acqprimary serialsprimary)) {
    $contact_info{$_} = [ $input->multi_param('contact_' . $_) ];
}

for my $cnt (0..scalar(@{$contact_info{'id'}})) {
    my %contact;
    my $real_contact;
    foreach (qw(id name position phone altphone fax email notes orderacquisition claimacquisition claimissues acqprimary serialsprimary)) {
        $contact{$_} = $contact_info{$_}->[$cnt];
        $real_contact = 1 if $contact{$_};
    }
    push @contacts, \%contact if $real_contact;
}

if($data{'name'}) {
    if ( $data{id} ) {
        # Update
        my $bookseller = Koha::Acquisition::Booksellers->find( $data{id} )->set(\%data)->store;
        # Delete existing contacts
        $bookseller->contacts->delete;
    } else {
        # Insert
        delete $data{id}; # Remove the key if exists
        my $bookseller = Koha::Acquisition::Bookseller->new( \%data )->store;
        $data{id} = $bookseller->id;
    }
    # Insert contacts
    for my $contact ( @contacts ) {
        $contact->{booksellerid} = $data{id};
        Koha::Acquisition::Bookseller::Contact->new( $contact )->store
    }

    #redirect to booksellers.pl
    print $input->redirect("booksellers.pl?booksellerid=".$data{id});
} else {
    print $input->redirect("supplier.pl?op=enter"); # fail silently.
}
