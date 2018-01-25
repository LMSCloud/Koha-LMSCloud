#!/usr/bin/perl

# This script inserts / updates records in DB tables authorised_values and insertinto_marc_subfield_structure
# that are required for the aggregated statistics type 'DBS'.
# 'DBS' evaluates the field items.coded_location_qualifier in some sql select statements.

use strict;
use warnings;

# CPAN modules
use DBI;
use C4::Context;
use Koha::Database;

my $debug = 1;

my $sth;

my $schema = Koha::Database->new()->schema();

my $dbh = C4::Context->dbh;
$|=1; # flushes output

local $dbh->{RaiseError} = 0;

sub insertinto_authorised_values {
	print "insertinto_authorised_values: Start\n" if $debug;

    my $loadvalues = [
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'F_B_F', 
          'lib'              => 'Freihand - Printmedien Schöne Literatur', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'F_B_J', 
          'lib'              => 'Printmedien Kinder- und Jugendliteratur', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'F_B_N', 
          'lib'              => 'Freihand - Printmedien Sachliteratur', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'F_B_P', 
          'lib'              => 'Printmedien Zeitschriftenhefte', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'F_N_A', 
          'lib'              => 'Freihand - Non-Book-Medien analog und digital', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'F_N_O', 
          'lib'              => 'Freihand - Non-Book-Medien, übrige', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'M_B_F', 
          'lib'              => 'Magazin - Printmedien Schöne Literatur', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'M_B_J', 
          'lib'              => 'Magazin - Printmedien Kinder- und Jugendliteratur', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'M_B_N', 
          'lib'              => 'Magazin - Printmedien Sachliteratur', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'M_B_P', 
          'lib'              => 'Magazin - Printmedien Zeitschriftenhefte', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'M_N_A', 
          'lib'              => 'Magazin - Non-Book-Medien analog und digital', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'M_N_O', 
          'lib'              => 'Magazin - Non-Book-Medien analog und digital', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'N_N_N', 
          'lib'              => 'nicht belegt - keine Auswertung!', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        },
        { 'category'         => 'DBS_WERTE', 
          'authorised_value' => 'Z_A_E', 
          'lib'              => 'Virtuell - Alle eMedien', 
          'lib_opac'         => undef,    # results in NULL
          'imageurl'         => ''
        }
    ];

    foreach my $loadvalue (@$loadvalues) {
        print "insertinto_authorised_values: loop loadvalue->{'authorised_value'}:", $loadvalue->{'authorised_value'}, ":\n";

        $sth = $dbh->prepare(q{
            DELETE FROM authorised_values WHERE category = ? AND authorised_value = ?
        });
        $sth->execute($loadvalue->{'category'}, $loadvalue->{'authorised_value'});

        $sth = $dbh->prepare(q{
            INSERT INTO authorised_values (category, authorised_value, lib, lib_opac, imageurl) VALUES 
                (?,?,?,?,?);
        });
        $sth->execute($loadvalue->{'category'}, $loadvalue->{'authorised_value'}, $loadvalue->{'lib'}, $loadvalue->{'lib_opac'}, $loadvalue->{'imageurl'});

    }

	print "insertinto_authorised_values: End\n" if $debug;
}

sub insertinto_marc_subfield_structure {
	print "insertinto_marc_subfield_structure: Start\n" if $debug;

    my @frameworkcodes = ();
    my $loadvalues = [
        { 'tagfield'         => 952,
          'tagsubfield'      => 'f',
          'liblibrarian'     => 'DBS Merkmal',
          'libopac'          => 'DBS Merkmal',
          'repeatable'       => 0,
          'mandatory'        => 1,
          'kohafield'        => 'items.coded_location_qualifier',
          'tab'              => 10,
          'authorised_value' => 'DBS_WERTE',
          'authtypecode'     => '',
          'value_builder'    => '',
          'isurl'            => 0,
          'hidden'           => 0,
          'frameworkcode'    => '',
          'seealso'          => undef,    # results in NULL
          'link'             => '',
          'defaultvalue'     => '',
          'maxlength'        => 9999
        }
    ];

    # select frameworkcode of frameworks to be updated
    $sth = $dbh->prepare(q{
        SELECT frameworkcode FROM marc_subfield_structure WHERE tagfield=952 AND tagsubfield="f" 
    });
    $sth->execute();
    while ( my ($frameworkcode) = $sth->fetchrow ) {
        push @frameworkcodes, $frameworkcode;
        #print "insertinto_marc_subfield_structure: frameworkcode:$frameworkcode: frameworkcodes[", scalar(@frameworkcodes)-1, "]:$frameworkcodes[scalar(@frameworkcodes)-1]:\n" if $debug;
    }

    foreach my $loadvalue (@$loadvalues) {

        foreach my $frameworkcode (@frameworkcodes) {
            print "insertinto_marc_subfield_structure: loop loadvalue->{'liblibrarian'}:", $loadvalue->{'liblibrarian'}, ": frameworkcode:$frameworkcode:\n";

            $sth = $dbh->prepare(q{
                DELETE FROM marc_subfield_structure WHERE tagfield = ? AND tagsubfield = ? AND frameworkcode = ?
            });
            $sth->execute($loadvalue->{'tagfield'}, $loadvalue->{'tagsubfield'}, $frameworkcode);

            $sth = $dbh->prepare(q{
                INSERT INTO marc_subfield_structure (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue, maxlength) VALUES 
                    (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);
            });
            $sth->execute(
                $loadvalue->{'tagfield'},
                $loadvalue->{'tagsubfield'},
                $loadvalue->{'liblibrarian'},
                $loadvalue->{'libopac'},
                $loadvalue->{'repeatable'},
                $loadvalue->{'mandatory'},
                $loadvalue->{'kohafield'},
                $loadvalue->{'tab'},
                $loadvalue->{'authorised_value'},
                $loadvalue->{'authtypecode'},
                $loadvalue->{'value_builder'},
                $loadvalue->{'isurl'},
                $loadvalue->{'hidden'},
                $frameworkcode,
                $loadvalue->{'seealso'},
                $loadvalue->{'link'},
                $loadvalue->{'defaultvalue'},
                $loadvalue->{'maxlength'}
            );
        }
    }

	print "insertinto_marc_subfield_structure: End\n" if $debug;
}


&insertinto_authorised_values();
&insertinto_marc_subfield_structure();
