#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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

use Modern::Perl;
use C4::Output;
use C4::Auth;
use CGI qw ( -utf8 );
use C4::Context;

use Koha::Authority::Types;
use Koha::AuthorisedValueCategories;
use Koha::Filter::MARC::ViewPolicy;

use List::MoreUtils qw( uniq );

my $input         = CGI->new;
my $tagfield      = $input->param('tagfield');
my $tagsubfield   = $input->param('tagsubfield');
my $frameworkcode = $input->param('frameworkcode');
my $pkfield       = "tagfield";
my $offset        = $input->param('offset');
$offset = 0 if not defined $offset or $offset < 0;
my $script_name   = "/cgi-bin/koha/admin/marc_subfields_structure.pl";

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "admin/marc_subfields_structure.tt",
        query           => $input,
        type            => "intranet",
        flagsrequired   => { parameters => 'manage_marc_frameworks' },
        debug           => 1,
    }
);
my $cache = Koha::Caches->get_instance();

my $op       = $input->param('op') || "";
$tagfield =~ s/\,//g;

if ($op) {
    $template->param(
        script_name   => $script_name,
        tagfield      => $tagfield,
        frameworkcode => $frameworkcode,
        $op           => 1
    );    # we show only the TMPL_VAR names $op
}
else {
    $template->param(
        script_name   => $script_name,
        tagfield      => $tagfield,
        frameworkcode => $frameworkcode,
        else          => 1
    );    # we show only the TMPL_VAR names $op
}

################## ADD_FORM ##################################
# called by default. Used to create form to add or  modify a record
if ( $op eq 'add_form' ) {
    my $dbh            = C4::Context->dbh;

    # builds kohafield tables
    my @kohafields;
    push @kohafields, "";
    my $sth2 = $dbh->prepare("SHOW COLUMNS from biblio");
    $sth2->execute;
    while ( ( my $field ) = $sth2->fetchrow_array ) {
        push @kohafields, "biblio." . $field;
    }
    $sth2 = $dbh->prepare("SHOW COLUMNS from biblioitems");
    $sth2->execute;
    while ( ( my $field ) = $sth2->fetchrow_array ) {
        if ( $field eq 'notes' ) { $field = 'bnotes'; }
        push @kohafields, "biblioitems." . $field;
    }
    $sth2 = $dbh->prepare("SHOW COLUMNS from items");
    $sth2->execute;
    while ( ( my $field ) = $sth2->fetchrow_array ) {
        push @kohafields, "items." . $field;
    }

    # build authorised value list
    $sth2->finish;
    $sth2 = $dbh->prepare("select distinct category from authorised_values");
    $sth2->execute;
    my @av_cat = Koha::AuthorisedValueCategories->search;
    my @authorised_values = map { $_->category_name } @av_cat;

    # build thesaurus categories list
    my @authtypes = uniq( "", map { $_->authtypecode } Koha::Authority::Types->search );

    # build value_builder list
    my @value_builder = ('');

    # read value_builder directory.
    # 2 cases here : on CVS install, $cgidir does not need a /cgi-bin
    # on a standard install, /cgi-bin need to be added.
    # test one, then the other
    my $cgidir = C4::Context->config('intranetdir') . "/cgi-bin";
    unless ( opendir( DIR, "$cgidir/cataloguing/value_builder" ) ) {
        $cgidir = C4::Context->config('intranetdir');
        opendir( DIR, "$cgidir/cataloguing/value_builder" )
          || die "can't opendir $cgidir/value_builder: $!";
    }
    while ( my $line = readdir(DIR) ) {
        if ( $line =~ /\.pl$/ &&
             $line !~ /EXAMPLE\.pl$/ ) { # documentation purposes
            push( @value_builder, $line );
        }
    }
    @value_builder= sort {$a cmp $b} @value_builder;
    closedir DIR;

    # build values list
    my $mss = Koha::MarcSubfieldStructures->search(
        { tagfield => $tagfield, frameworkcode => $frameworkcode },
        { order_by => 'display_order' }
    )->unblessed;
    my @loop_data = ();
    my $i         = 0;
    for my $m ( @$mss ) {
        my %row_data = %$m;    # get a fresh hash for the row data
        $row_data{subfieldcode}      = $m->{tagsubfield};
        $row_data{urisubfieldcode}   = $row_data{subfieldcode} eq '%' ? 'pct' : $row_data{subfieldcode};
        $row_data{kohafields}        = \@kohafields;
        $row_data{authorised_values} = \@authorised_values;
        $row_data{value_builders}    = \@value_builder;
        $row_data{authtypes}         = \@authtypes;
        $row_data{row}               = $i;

        if ( defined $m->{kohafield}
            and $m->{kohafield} eq 'biblio.biblionumber' )
        {
            my $hidden_opac = Koha::Filter::MARC::ViewPolicy->should_hide_marc(
                    {
                        frameworkcode => $frameworkcode,
                        interface     => "opac",
                    }
                )->{biblionumber};

            my $hidden_intranet = Koha::Filter::MARC::ViewPolicy->should_hide_marc(
                    {
                        frameworkcode => $frameworkcode,
                        interface     => "intranet",
                    }
                )->{biblionumber};

            if ( $hidden_opac or $hidden_intranet ) {
                # We should allow editing for fixing it
                $row_data{hidden_protected} = 0;
            }
            else {
                $row_data{hidden_protected} = 1;
            }
        }

        push( @loop_data, \%row_data );
        $i++;
    }

    # Add a new row for the "New" tab
    my %row_data;    # get a fresh hash for the row data
    $row_data{'new_subfield'}    = 1;
    $row_data{'subfieldcode'}    = '';
    $row_data{'maxlength'}       = 9999;
    $row_data{tab}               = -1;                    #ignore
    $row_data{tagsubfield}       = "";
    $row_data{liblibrarian}      = "";
    $row_data{libopac}           = "";
    $row_data{seealso}           = "";
    $row_data{hidden}            = "";
    $row_data{repeatable}        = 0;
    $row_data{mandatory}         = 0;
    $row_data{important}         = 0;
    $row_data{isurl}             = 0;
    $row_data{kohafields}        = \@kohafields;
    $row_data{authorised_values} = \@authorised_values;
    $row_data{value_builders}    = \@value_builder;
    $row_data{authtypes}         = \@authtypes;
    $row_data{link}              = "";
    $row_data{row}               = $i;
    push( @loop_data, \%row_data );

    $template->param( 'use_heading_flags_p'      => 1 );
    $template->param( 'heading_edit_subfields_p' => 1 );
    $template->param(
        action   => "Edit subfields",
        tagfield => $tagfield,
        loop           => \@loop_data,
        more_tag       => $tagfield
    );

    # END $OP eq ADD_FORM
################## ADD_VALIDATE ##################################
    # called by add_form, used to insert/modify data in DB
}
elsif ( $op eq 'add_validate' ) {
    my $dbh = C4::Context->dbh;
    $template->param( tagfield => "$input->param('tagfield')" );
    my @tagsubfield       = $input->multi_param('tagsubfield');
    my @liblibrarian      = $input->multi_param('liblibrarian');
    my @libopac           = $input->multi_param('libopac');
    my @kohafield         = $input->multi_param('kohafield');
    my @tab               = $input->multi_param('tab');
    my @seealso           = $input->multi_param('seealso');
    my @hidden            = $input->multi_param('hidden');
    my @authorised_values = $input->multi_param('authorised_value');
    my @authtypecodes     = $input->multi_param('authtypecode');
    my @value_builder     = $input->multi_param('value_builder');
    my @link              = $input->multi_param('link');
    my @defaultvalue      = $input->multi_param('defaultvalue');
    my @maxlength         = $input->multi_param('maxlength');

    my $display_order;
    for ( my $i = 0 ; $i <= $#tagsubfield ; $i++ ) {
        my $tagfield    = $input->param('tagfield');
        my $tagsubfield = $tagsubfield[$i];
        $tagsubfield = "@" unless $tagsubfield ne '';
        my $liblibrarian     = $liblibrarian[$i];
        my $libopac          = $libopac[$i];
        my $repeatable       = $input->param("repeatable$i") ? 1 : 0;
        my $mandatory        = $input->param("mandatory$i") ? 1 : 0;
        my $important        = $input->param("important$i") ? 1 : 0;
        my $kohafield        = $kohafield[$i];
        my $tab              = $tab[$i];
        my $seealso          = $seealso[$i];
        my $authorised_value = $authorised_values[$i];
        my $authtypecode     = $authtypecodes[$i];
        my $value_builder    = $value_builder[$i];
        my $hidden = $hidden[$i];                     #input->param("hidden$i");
        my $isurl  = $input->param("isurl$i") ? 1 : 0;
        my $link   = $link[$i];
        my $defaultvalue = $defaultvalue[$i];
        my $maxlength = $maxlength[$i] ? $maxlength[$i] : 9999;
        
        if (defined($liblibrarian) && $liblibrarian ne "") {
            my $mss = Koha::MarcSubfieldStructures->find({tagfield => $tagfield, tagsubfield => $tagsubfield, frameworkcode => $frameworkcode });
            if ($mss) {
                $mss->update(
                    {
                        liblibrarian     => $liblibrarian,
                        libopac          => $libopac,
                        repeatable       => $repeatable,
                        mandatory        => $mandatory,
                        important        => $important,
                        kohafield        => $kohafield,
                        tab              => $tab,
                        seealso          => $seealso,
                        authorised_value => $authorised_value,
                        authtypecode     => $authtypecode,
                        value_builder    => $value_builder,
                        hidden           => $hidden,
                        isurl            => $isurl,
                        link             => $link,
                        defaultvalue     => $defaultvalue,
                        maxlength        => $maxlength,
                        display_order    => $display_order->{$tagfield} || 0
                    }
                );
            } else {
                if( $frameworkcode ne q{} ) {
                    # BZ 19096: Overwrite kohafield from Default when adding a new record
                     my $rec = Koha::MarcSubfieldStructures->find( q{}, $tagfield, $tagsubfield );
                    $kohafield = $rec->kohafield if $rec;
                }
                Koha::MarcSubfieldStructure->new(
                    {
                        tagfield         => $tagfield,
                        tagsubfield      => $tagsubfield,
                        liblibrarian     => $liblibrarian,
                        libopac          => $libopac,
                        repeatable       => $repeatable,
                        mandatory        => $mandatory,
                        important        => $important,
                        kohafield        => $kohafield,
                        tab              => $tab,
                        seealso          => $seealso,
                        authorised_value => $authorised_value,
                        authtypecode     => $authtypecode,
                        value_builder    => $value_builder,
                        hidden           => $hidden,
                        isurl            => $isurl,
                        frameworkcode    => $frameworkcode,
                        link             => $link,
                        defaultvalue     => $defaultvalue,
                        maxlength        => $maxlength,
                        display_order    => $display_order->{$tagfield} || 0,
                    }
                )->store;
            }
            $display_order->{$tagfield}++;
        }
    }
    $cache->clear_from_cache("MarcStructure-0-$frameworkcode");
    $cache->clear_from_cache("MarcStructure-1-$frameworkcode");
    $cache->clear_from_cache("default_value_for_mod_marc-");
    $cache->clear_from_cache("MarcSubfieldStructure-$frameworkcode");

    print $input->redirect("/cgi-bin/koha/admin/marc_subfields_structure.pl?tagfield=$tagfield&amp;frameworkcode=$frameworkcode");
    exit;

    # END $OP eq ADD_VALIDATE
################## DELETE_CONFIRM ##################################
    # called by default form, used to confirm deletion of data in DB
}
elsif ( $op eq 'delete_confirm' ) {
    my $mss = Koha::MarcSubfieldStructures->find(
        {
            tagfield      => $tagfield,
            tagsubfield   => $tagsubfield,
            frameworkcode => $frameworkcode
        }
    );
    $template->param(
        mss => $mss,
        delete_link   => $script_name,
    );

    # END $OP eq DELETE_CONFIRM
################## DELETE_CONFIRMED ##################################
  # called by delete_confirm, used to effectively confirm deletion of data in DB
}
elsif ( $op eq 'delete_confirmed' ) {
    Koha::MarcSubfieldStructures->find(
        {
            tagfield      => $tagfield,
            tagsubfield   => $tagsubfield,
            frameworkcode => $frameworkcode
        }
    )->delete;

    $cache->clear_from_cache("MarcStructure-0-$frameworkcode");
    $cache->clear_from_cache("MarcStructure-1-$frameworkcode");
    $cache->clear_from_cache("default_value_for_mod_marc-");
    $cache->clear_from_cache("MarcSubfieldStructure-$frameworkcode");
    print $input->redirect("/cgi-bin/koha/admin/marc_subfields_structure.pl?tagfield=$tagfield&amp;frameworkcode=$frameworkcode");
    exit;

    # END $OP eq DELETE_CONFIRMED
################## DEFAULT ##################################
}
else {    # DEFAULT
    my $mss = Koha::MarcSubfieldStructures->search(
        {
            tagfield      => { -like => "$tagfield%" },
            frameworkcode => $frameworkcode
        },
        { order_by => [ 'tagfield', 'display_order' ] }
    )->unblessed;

    $template->param( loop => $mss );
    $template->param(
        edit_tagfield      => $tagfield,
        edit_frameworkcode => $frameworkcode
    );

}    #---- END $OP eq DEFAULT

output_html_with_http_headers $input, $cookie, $template->output;
