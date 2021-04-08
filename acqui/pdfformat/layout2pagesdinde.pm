package pdfformat::layout2pagesdinde;

# Script to print the order in German DIN format. Initial for Duisburg public library (Stadtbibliothek Duisburg)
# Written in Feb. 2021 by m.m.oehme@gmail.com
# Based on:
#   example script to print a basketgroup
#   written 07/11/08 by john.soros@biblibre.com and paul.poulain@biblibre.com
#
# Copyright 2021 M.Oehme
#
# This file is only useful as part of Koha.
#
# Koha, and this file too, is free software; you can redistribute it and/or modify it
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

use vars qw(@ISA @EXPORT);
use MIME::Base64;
use List::MoreUtils qw/uniq/;
use Modern::Perl;
use utf8;

use C4::Acquisition;
use Koha::Number::Price;
use Koha::DateUtils;
use Koha::Libraries;

use PDF::API2;
use PDF::Table;

BEGIN {
    use Exporter   ();
    our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
    @ISA    = qw(Exporter);
    @EXPORT = qw(printpdf);
}
#be careful, all the sizes (height, width, etc...) are in mm, not PostScript points (the default measurment of PDF::API2).
use constant mm => 25.4 / 72;
#The constants exported transform that into PostScript points (/mm for milimeter, /in for inch, pt is postscript point, and as so is there only to show what is happening.
#use constant in => 1 / 72;
#use constant pt => 1;

#A4 paper specs
my ($height, $width) = (297, 210);

sub printpage1 {
    my ($pdf, $basketgroup, $hbaskets, $bookseller, $GSTrate, $orders) = @_;

    my $libraryname       = C4::Context->preference("LibraryName");
    my $billing_library   = Koha::Libraries->find( $basketgroup->{billingplace} );
    my $delivery_library  = Koha::Libraries->find( $basketgroup->{deliveryplace} );
    my $freedeliveryplace = $basketgroup->{freedeliveryplace};

    # open 1st page (with the header)
    #my $page = $pdf->openpage(1);
    my $page = $pdf->page();
    my $text = $page->text;

    ############################################################################
    # print library name
    $text->font( $pdf->corefont("Arial", -encoding => "utf8"), 6/mm );
    $text->translate(25/mm,  ($height-28.5)/mm);
    $text->text($libraryname);

    ############################################################################
    # print sender line in address field
    my $sender=$billing_library->branchname." - ". $billing_library->branchaddress1." - ". $billing_library->branchzip." ".$billing_library->branchcity;
    $text->font( $pdf->corefont("Arial", -encoding => "utf8"), 3/mm );
    $text->translate(25/mm,  ($height-55)/mm);
    $text->text($sender, -underline => 'auto');

    ############################################################################
    # print the address field  (bookseller infos)
    $text->font( $pdf->corefont("Arial", -encoding => "utf8"), 4/mm );
    $text->translate(25/mm,  ($height-65)/mm);
    $text->text($bookseller->name);
    #  $bookseller->postal means address and can contain more than one line, so i split it on "\n" to an array and itterate thru every line
    if ( $bookseller->postal) {
      my @lines=split( /\n/, $bookseller->postal);
      my $vpos =70;
      foreach  (@lines) {
        $text->translate(25/mm,  (($height-$vpos)/mm));
        $text->text($_);
        $vpos=$vpos+5;
        last if $vpos>100;
      }
    }

    ############################################################################
    # print the date
    my $today = "Datum ".output_pref({ dt => dt_from_string, dateonly => 1 });
    $text->translate(195/mm,  ($height-75)/mm);
    $text->text_right($today);

    ############################################################################
    # Ordernr (booksellernote)
    $text->font( $pdf->corefont("Arial-Bold", -encoding => "utf8"), 5/mm );
    $text->translate(25/mm,  ($height-115)/mm);
    $text->text(("Bestellung ".$bookseller->notes), -underline => 'auto');

    $text->font( $pdf->corefont("Arial", -encoding => "utf8"), 4/mm );
    $text->translate(25/mm,  ($height-120)/mm);
    $text->text("(bei der Rechnungsstellung bitte unbedingt angeben!)");

    $text->translate(25/mm,  ($height-130)/mm);
    $text->text("Wir bitten um Lieferung der ab Seite 2 aufgelisteten Positionen an die genannte Lieferadresse.");

    ############################################################################
    # print delivery infos
    $text->font( $pdf->corefont("Arial", -encoding => "utf8"), 4/mm );
    $text->translate(25/mm,  ($height-145)/mm);
    $text->text("Lieferadresse", -underline => 'auto');
    if ($freedeliveryplace) {
        my $start = 150;
        my @fdp = split('\n', $freedeliveryplace);
        foreach (@fdp) {
            $text->translate( 25 / mm, ( $height - $start ) / mm );
            if ($_) {
                $text->text($_);
                $start += 5;
            }
        }
    }
    else {
        my $start = 150;
        my @fdp = ($delivery_library->branchname, $delivery_library->branchaddress1,
                   $delivery_library->branchaddress2, $delivery_library->branchaddress3,
                   join(' ', $delivery_library->branchzip, $delivery_library->branchcity)
	          );
        foreach (@fdp) {
            if ($_) {
                $text->translate( 25/mm, ( $height - $start )/mm );
                $text->text($_);
                $start += 5;
            }
        }
    }

    ############################################################################
    #print billing infos
    $text->font( $pdf->corefont("Arial", -encoding => "utf8"), 4/mm );
    $text->translate(125/mm,  ($height-145)/mm);
    $text->text("Rechnungsadresse", -underline => 'auto');

    my $start = 150;
    my @pbi = ($billing_library->branchname, $billing_library->branchaddress1,
               $billing_library->branchaddress2, $billing_library->branchaddress3,
               join(' ', $billing_library->branchzip, $billing_library->branchcity));
    foreach (@pbi) {
        if ($_) {
            $text->translate( 125 / mm, ( $height - $start ) / mm );
            $text->text($_);
            $start += 5;
        }
    }

    ############################################################################
    ## collect all the money  ;-)
    my ($grandtotal_rrp_tax_excluded,     # Einzelpreis netto
        $grandtotaltax_value,             # Steuer
        $grandtotaldiscount,              # Rabatt
        $grandtotal_tax_excluded,         # Geamtpreis netto
        $grandtotal_tax_included);        # Gesamtpreis brutto

    # calculate each basket total
    for my $basket (@$hbaskets) {
        my ($total_rrp_tax_excluded,
            $totaltax_value,
            $totaldiscount,
            $total_tax_excluded,
            $total_tax_included );

        # calculate each order total
        my $ords = $orders->{$basket->{basketno}};
        foreach my $ord (@$ords) {
            $total_rrp_tax_excluded += get_rounded_price($ord->{rrp_tax_excluded}) * $ord->{quantity};
            $totaltax_value += $ord->{tax_value};
            $totaldiscount += (get_rounded_price($ord->{rrp_tax_excluded}) - get_rounded_price($ord->{ecost_tax_excluded}) ) * $ord->{quantity};
            $total_tax_excluded += $ord->{total_tax_excluded};
            $total_tax_included += $ord->{total_tax_included};
        }
        $grandtotal_rrp_tax_excluded += $total_rrp_tax_excluded;
        $grandtotaltax_value += $totaltax_value;
        $grandtotaldiscount += $totaldiscount;
        $grandtotal_tax_excluded += $total_tax_excluded;
        $grandtotal_tax_included += $total_tax_included;
    }

    ############################################################################
    ## data output
    $text->font( $pdf->corefont("Arial", -encoding => "utf8"), 4/mm );
    $text->translate(25/mm,  ($height-180)/mm);
    $text->text("Zusammenfassung", -underline => 'auto');
    #$text->text(($basketgroup->{'name'}."(".$basketgroup->{'id'}."):"),-underline=>'auto') ;

    $text->translate(75/mm,  ($height-180)/mm);
    $text->text("Summe");
    $text->translate(($width-40)/mm,  ($height-180)/mm);
    $text->text_right((Koha::Number::Price->new($grandtotal_rrp_tax_excluded)->format." Euro"));

    $text->translate(75/mm,  ($height-185)/mm);
    $text->text("./. Rabatt");
    $text->translate(($width-40)/mm,  ($height-185)/mm);
    $text->text_right((Koha::Number::Price->new($grandtotaldiscount)->format." Euro"));

    my $content = $page->gfx();
    $content->move(75/mm, ($height-186)/mm);
    $content->hline(($width-40)/mm);
    $content->stroke;

    $text->translate(75/mm,  ($height-190)/mm);
    $text->text("Gesamt (Netto)");
    $text->translate(($width-40)/mm,  ($height-190)/mm);
    $text->text_right((Koha::Number::Price->new($grandtotal_tax_excluded)->format." Euro"));

    $text->translate(75/mm,  ($height-195)/mm);
    $text->text("MwSt.");
    $text->translate(($width-40)/mm,  ($height-195)/mm);
    $text->text_right((Koha::Number::Price->new($grandtotaltax_value)->format." Euro"));

    $content->move(75/mm, ($height-196)/mm);
    $content->hline(($width-40)/mm);
    $content->stroke;

    $text->font( $pdf->corefont("Arial-Bold", -encoding => "utf8"), 4/mm );
    $text->translate(75/mm,  ($height-200)/mm);
    $text->text("Gesamt (Brutto)");
    $text->translate(($width-40)/mm,  ($height-200)/mm);
    $text->text_right((Koha::Number::Price->new($grandtotal_tax_included)->format." Euro"));

    $content->move(75/mm, ($height-201)/mm);
    $content->hline(($width-40)/mm);
    $content->stroke;
    $content->move(75/mm, ($height-202)/mm);
    $content->hline(($width-40)/mm);
    $content->stroke;

    ############################################################################
    ## signature
    $text->font( $pdf->corefont("Arial", -encoding => "utf8"), 4/mm );
    $text->translate(25/mm,  ($height-235)/mm);
    $text->text("Mit freundlichen Grüßen");
    $text->translate(25/mm,  ($height-240)/mm);
    $text->text("Im Auftrag");
}

sub printorders {
    my ($pdf, $basketgroup, $baskets, $orders) = @_;
    my $cur_format = C4::Context->preference("CurrencyFormat");

    $pdf->mediabox($height/mm, $width/mm);
    for my $basket (@$baskets){
        my $page = $pdf->page();
        my $billing_library  = Koha::Libraries->find( $basket->{billingplace} );
        my $delivery_library = Koha::Libraries->find( $basket->{deliveryplace} );
        my $text = $page->text;

        ########################################################################
        # print basket header (box)
        my $box = $page->gfx;
        $box->rectxy((25)/mm, ($height - 10)/mm, ($width - 10)/mm, ($height - 25)/mm);
        $box->stroke;

        ########################################################################
        # print basket header (text)
        $text->font( $pdf->corefont("Arial", -encoding => "utf8"), 6/mm );
        $text->translate(30/mm,  ($height-15)/mm);
        $text->text("Bestellung: ".$basketgroup->{'name'}." (".$basketgroup->{'id'}.")");

        $text->font( $pdf->corefont("Arial", -encoding => "utf8"), 4/mm );
        $text->translate(30/mm,  ($height-20)/mm);
 	      $text->text(("Hinweis: ".$basket->{booksellernote}));

        ########################################################################
        # print the orders in the basketgroup
        my $pdftable = PDF::Table->new();
        my $abaskets;
        my $arrbasket;

        my @keys = ("Best.", "Titel", "Anz.", "Preis\n(Netto)", "Rabatt", "Gesamt\n(Netto)", "MwSt.", "Gesamt\n(Brutto)");
        for my $bkey (@keys) {
            push(@$arrbasket, $bkey);
        }
        push(@$abaskets, $arrbasket);

        my $titleinfo;

        foreach my $line (@{$orders->{$basket->{basketno}}}) {
            $arrbasket = undef;
            $titleinfo = "";
            
            $titleinfo =  $line->{title} . " / " . $line->{author} .
                ( $line->{isbn} ? " ISBN: " . $line->{isbn} : '' ) .
                ( $line->{issn} ? " ISSN: " . $line->{issn} : '' ) .
                ( $line->{ean}  ? " EAN, Verlegernr., o.ä.: " . $line->{ean} : '' ) .
                ( $line->{en} ? " EN: " . $line->{en} : '' ) .
                ( $line->{itemtype} ? ", " . $line->{itemtype} : '' ) .
                ( $line->{edition} ? ", " . $line->{edition} : '' ) .
                ( $line->{publishercode} ? ' published by '. $line->{publishercode} : '') .
                ( $line->{publicationyear} ? ', '. $line->{publicationyear} : '') .
                ( $line->{copyrightdate} ? ' '. $line->{copyrightdate} : '');

            push( @$arrbasket,
               ($basket->{basketno}."-".$line->{ordernumber}),
               $titleinfo. ($line->{order_vendornote} ? "\n----------------\nLieferhinweis: " . $line->{order_vendornote} : ''),
               $line->{quantity},
               Koha::Number::Price->new( $line->{rrp_tax_excluded} )->format,
               (
                 Koha::Number::Price->new( $line->{rrp_tax_excluded} - $line->{ecost_tax_excluded})->format."\n(".
                 Koha::Number::Price->new( $line->{discount} )->format . '%)',
               ) ,
               Koha::Number::Price->new( $line->{total_tax_excluded} )->format,
               (
                 Koha::Number::Price->new( $line->{tax_value} )->format."\n(".
                 Koha::Number::Price->new( $line->{tax_rate} * 100 )->format . '%)'
               ),
    	         Koha::Number::Price->new( $line->{total_tax_included} )->format,
            );
            push(@$abaskets, $arrbasket);
        }
        $pdftable->table($pdf, $page, $abaskets,
            x => 25/mm,
            start_y => 270/mm,
            w => ($width - 35)/mm,
            start_h => 240/mm,
            next_y  => 285/mm,
            next_h  => 255/mm,
            padding => 2,
            padding_right => 2,
            background_color_odd  => "lightgray",
            font       => $pdf->corefont("Arial", -encoding => "utf8"),
            font_size => 3/mm,
            header_props   =>    {
                font       => $pdf->corefont("Arial", -encoding => "utf8"),
                font_size  => 9,
                bg_color   => 'gray',
                repeat     => 1,
            },
            column_props => [
                { justify => 'left',  },     # One of left|right ,
                { min_w => 65/mm,            # Minimum column width.
                  max_w => 65/mm,            # Maximum column width.
                  justify => 'left',         # One of left|right ,
                },
                { justify => 'right', }, # One of left|right ,
                { justify => 'right', }, # One of left|right ,
                { justify => 'right', }, # One of left|right ,
                { justify => 'right', }, # One of left|right ,
                { justify => 'right', }, # One of left|right ,
                { justify => 'right', }, # One of left|right ,
            ],
        );
    }
    $pdf->mediabox($width/mm, $height/mm);
}

sub printfooters {
    my ($pdf) = @_;
    for (my $i=1;$i <= $pdf->pages;$i++) {
        my $page = $pdf->openpage($i);
        my $text = $page->text;
        $text->font( $pdf->corefont("Arial", -encoding => "utf8"), 3/mm );
        $text->translate(105/mm,  20/mm);
        $text->text_center("Seite $i / ".$pdf->pages);
    }
}

sub printpdf {
    my ($basketgroup, $bookseller, $baskets, $orders, $GST) = @_;

    # we dont use template, but let the code as comment if someone in the future will do
    # open the default PDF that will be used for base (1st page already filled)
    #   my $pdf_template = C4::Context->config('intrahtdocs') . '/' . C4::Context->preference('template') . '/pdf/layout2pagesdin.pdf';
    #   my $pdf = PDF::API2->open($pdf_template);
    my $pdf = PDF::API2->new();
    $pdf->pageLabel( 0, { -style => 'roman', } ); # start with roman numbering

    # fill the 1st page
    printpage1($pdf, $basketgroup, $baskets, $bookseller, $GST, $orders);
    # fill other pages (orders)
    printorders($pdf, $basketgroup, $baskets, $orders);
    # print something on each page (usually the footer, but you could also put a header
    printfooters($pdf);
    return $pdf->stringify;
}

1;
