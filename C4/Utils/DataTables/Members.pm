package C4::Utils::DataTables::Members;

use Modern::Perl;
use C4::Context;
use C4::Utils::DataTables;
use Koha::DateUtils;
use C4::Members::Attributes qw(SearchIdMatchingAttribute );

sub search {
    my ( $params ) = @_;
    my $searchmember = $params->{searchmember};
    my $firstletter = $params->{firstletter};
    my $categorycode = $params->{categorycode};
    my $branchcode = $params->{branchcode};
    my $searchtype = $params->{searchtype} || 'contain';
    my $searchfieldstype = $params->{searchfieldstype} || 'standard';
    my $dt_params = $params->{dt_params};
    my $chargesfrom = $params->{chargesfrom};
    my $chargesto = $params->{chargesto};
    my $chargessince =  $params->{chargessince};
    my $accountexpiresto = $params->{accountexpiresto};
    my $accountexpiresfrom = $params->{accountexpiresfrom};
    my $debarreduntilto = $params->{debarreduntilto};
    my $debarreduntilfrom = $params->{debarreduntilfrom};
    my $lastlettercode = $params->{lastlettercode};
    my $agerangestart = $params->{agerangestart};
    my $agerangeend = $params->{agerangeend};
    my $overduelevel = $params->{overduelevel};
    my $inactivesince = $params->{inactivesince};
    my $validemailavailable = $params->{validemailavailable};
    my $patronlistid = $params->{patronlistid};
    my $issuecountstart = $params->{issuecountstart};
    my $issuecountend = $params->{issuecountend};
    my $return_borrower_attributes = $params->{return_borrower_attributes};

    unless ( $searchmember ) {
        $searchmember = $dt_params->{sSearch} // '';
    }

    # If branches are independent and user is not superlibrarian
    # The search has to be only on the user branch
    my $userenv = C4::Context->userenv;
    my $logged_in_user = Koha::Patrons->find( $userenv->{number} );
    my @restricted_branchcodes = $logged_in_user->libraries_where_can_see_patrons;

    my ($sth, $query, $iTotalQuery, $iTotalRecords, $iTotalDisplayRecords);
    my $dbh = C4::Context->dbh;
    # Get the iTotalRecords DataTable variable
    $query = $iTotalQuery = "SELECT COUNT(borrowers.borrowernumber) FROM borrowers";
    if ( @restricted_branchcodes ) {
        $iTotalQuery .= " WHERE borrowers.branchcode IN (" . join( ',', ('?') x @restricted_branchcodes ) . ")";
    }
    ($iTotalRecords) = $dbh->selectrow_array( $iTotalQuery, undef, @restricted_branchcodes );

    # Do that after iTotalQuery!
    if ( defined $branchcode and $branchcode ) {
        @restricted_branchcodes = @restricted_branchcodes
            ? grep { /^$branchcode$/ } @restricted_branchcodes
                ? ($branchcode)
                : (undef) # Do not return any results
            : ($branchcode);
    }

    if ( $searchfieldstype eq 'dateofbirth' ) {
        # Return an empty list if the date of birth is not correctly formatted
        $searchmember = eval { output_pref( { str => $searchmember, dateformat => 'iso', dateonly => 1 } ); };
        if ( $@ or not $searchmember ) {
            return {
                iTotalRecords        => $iTotalRecords,
                iTotalDisplayRecords => 0,
                patrons              => [],
            };
        }
    }

    my $select = "SELECT
        borrowers.borrowernumber, borrowers.surname, borrowers.firstname,
        borrowers.streetnumber, borrowers.streettype, borrowers.address,
        borrowers.address2, borrowers.city, borrowers.state, borrowers.zipcode,
        borrowers.country, cardnumber, borrowers.dateexpiry,
        borrowers.borrowernotes, borrowers.branchcode, borrowers.email,
        borrowers.userid, borrowers.dateofbirth, borrowers.categorycode,
        categories.description AS category_description, categories.category_type,
        branches.branchname, borrowers.lost, borrowers.gonenoaddress,
        debar.expiration as debarred, debar.comment as debarredcomment ";
    my $from = "FROM borrowers
        LEFT JOIN branches ON borrowers.branchcode = branches.branchcode
        LEFT JOIN categories ON borrowers.categorycode = categories.categorycode
        LEFT JOIN (SELECT borrowernumber, IFNULL('9999-12-31',max(expiration)) as expiration, GROUP_CONCAT(comment SEPARATOR ' / ') AS comment FROM borrower_debarments WHERE expiration > CURRENT_DATE() OR expiration IS NULL GROUP BY borrowernumber) AS debar on borrowers.borrowernumber = debar.borrowernumber ";
    my @where_args;
    my @where_strs;
    if(defined $firstletter and $firstletter ne '') {
        push @where_strs, "borrowers.surname LIKE ?";
        push @where_args, "$firstletter%";
    }
    if(defined $categorycode and $categorycode ne '') {
        push @where_strs, "borrowers.categorycode = ?";
        push @where_args, $categorycode;
    }
    if(@restricted_branchcodes ) {
        push @where_strs, "borrowers.branchcode IN (" . join( ',', ('?') x @restricted_branchcodes ) . ")";
        push @where_args, @restricted_branchcodes;
    }
    if ( defined($chargesfrom) && $chargesfrom =~ /^[0-9]+(\.+[0-9]+)?$/ ) {
        $chargesfrom += 0.0;
    } else {
        $chargesfrom = undef;
    }
    if ( defined($chargesto) && $chargesto =~ /^[0-9]+(\.+[0-9]+)?$/ ) {
        $chargesto += 0.0;
    } else {
        $chargesto = undef;
    }
    if (defined($chargesfrom) || defined($chargesto)) {
        my $add = "( EXISTS (SELECT 1 FROM accountlines a WHERE a.borrowernumber = borrowers.borrowernumber GROUP BY a.borrowernumber HAVING ";
        if ( defined($chargesfrom) && defined($chargesto) ) {
            if ( $chargesfrom == 0.0 && $chargesto == 0.0 ) {
                $add .= "COALESCE(SUM(a.amountoutstanding),0) = 0.0) OR NOT EXISTS (SELECT 1 FROM accountlines aa WHERE aa.borrowernumber = borrowers.borrowernumber) )";
            } else {
                $add .= "COALESCE(SUM(a.amountoutstanding),0) BETWEEN ? AND ?) ";
                $add .= "OR NOT EXISTS ( SELECT 1 FROM accountlines aa WHERE aa.borrowernumber = borrowers.borrowernumber) " if ( ( $chargesfrom == 0.0 || $chargesto == 0.0 ) && $chargesto >= $chargesfrom );
                $add .= " )";
                push @where_args, $chargesfrom, $chargesto;
            }
        }
        elsif ( defined($chargesfrom) ) {
            $add .= "SUM(a.amountoutstanding) >= ?) ";
            $add .= "OR NOT EXISTS (SELECT 1 FROM accountlines aa WHERE aa.borrowernumber = borrowers.borrowernumber) " if ( $chargesfrom == 0.0 );
            $add .= " )";
            push @where_args, $chargesfrom;
        }
        else {
            $add .= "SUM(a.amountoutstanding) <= ?) ";
            $add .= "OR NOT EXISTS (SELECT 1 FROM accountlines aa WHERE aa.borrowernumber = borrowers.borrowernumber) " if ( $chargesto == 0.0 );
            $add .= " )";
            push @where_args, $chargesto;
        }
        push @where_strs, $add;
    }
    if ( defined($chargessince) && $chargessince =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ) {
        push @where_strs, "EXISTS (SELECT 1 FROM accountlines al WHERE al.borrowernumber = borrowers.borrowernumber AND al.amountoutstanding >= 0.01 and al.date <= ?)";
        push @where_args, $chargessince;
    }
    if ( defined($accountexpiresto) && $accountexpiresto =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ) {
        push @where_strs, "borrowers.dateexpiry <= ?";
        push @where_args, $accountexpiresto;
    }
    if ( defined($accountexpiresfrom) && $accountexpiresfrom =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ) {
        push @where_strs, "borrowers.dateexpiry >= ?";
        push @where_args, $accountexpiresfrom;
    }
    if ( defined($debarreduntilto) && $debarreduntilto =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ) {
        push @where_strs, "borrowers.debarred <= ?";
        push @where_args, $debarreduntilto;
    }
    if ( defined($debarreduntilfrom) && $debarreduntilfrom =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ) {
        push @where_strs, "borrowers.debarred >= ?";
        push @where_args, $debarreduntilfrom;
    }
    if ( defined($lastlettercode) and $lastlettercode !~ /^\s*$/ ) {
        push @where_strs, "EXISTS (SELECT 1 FROM message_queue m WHERE m.borrowernumber = borrowers.borrowernumber AND m.letter_code = ? and m.time_queued = (SELECT MAX(time_queued) FROM message_queue mq WHERE mq.borrowernumber = borrowers.borrowernumber and status = ?))";
        push @where_args, $lastlettercode;
        push @where_args, 'sent';
    }
    if (defined($agerangestart) || defined($agerangeend)) {
        my $add = "TIMESTAMPDIFF(YEAR,borrowers.dateofbirth,CURDATE())";
        if ( defined($agerangestart) && $agerangestart =~ /^\d+$/ && defined($agerangeend) && $agerangeend =~ /^\d+$/ ) {
            $add .= " BETWEEN ? AND ?";
            push @where_strs, $add;
            push @where_args, $agerangestart, $agerangeend;
        }
        elsif ( defined($agerangestart) && $agerangestart =~ /^\d+$/ ) {
            $add .= " >= ?";
            push @where_strs, $add;
            push @where_args, $agerangestart;
        }
        elsif ( defined($agerangeend) && $agerangeend =~ /^\d+$/ ) {
            $add .= " <= ?";
            push @where_strs, $add;
            push @where_args, $agerangeend;
        }
    }
    if (defined($issuecountstart) || defined($issuecountend)) {
        my $add = "(SELECT COUNT(*) FROM issues iss WHERE iss.borrowernumber = borrowers.borrowernumber)";
        if ( defined($issuecountstart) && $issuecountstart =~ /^\d+$/ && defined($issuecountend) && $issuecountend =~ /^\d+$/ ) {
            $add .= " BETWEEN ? AND ?";
            push @where_strs, $add;
            push @where_args, $issuecountstart, $issuecountend;
        }
        elsif ( defined($issuecountstart) && $issuecountstart =~ /^\d+$/ ) {
            $add .= " >= ?";
            push @where_strs, $add;
            push @where_args, $issuecountstart;
        }
        elsif ( defined($issuecountend) && $issuecountend =~ /^\d+$/ ) {
            $add .= " <= ?";
            push @where_strs, $add;
            push @where_args, $issuecountend;
        }
    }
    if (defined($overduelevel) && $overduelevel =~ /^\d+$/ ) {
        push @where_strs, "EXISTS (SELECT 1 FROM issues i WHERE i.borrowernumber = borrowers.borrowernumber AND ? IN (SELECT max(claim_level) FROM overdue_issues o WHERE i.issue_id = o.issue_id GROUP BY o.issue_id))";
        push @where_args, $overduelevel;
    }
    if ( defined($inactivesince) && $inactivesince =~ /^([0-9]{4}-[0-9]{2}-[0-9]{2})/ ) {
        $inactivesince = "$1 23:59:59";
        push @where_strs, "NOT EXISTS (SELECT 1 FROM issues iss WHERE iss.borrowernumber = borrowers.borrowernumber AND iss.timestamp > ?)";
        push @where_strs, "NOT EXISTS (SELECT 1 FROM old_issues oiss WHERE oiss.borrowernumber = borrowers.borrowernumber AND oiss.timestamp > ?)";
        push @where_args, $inactivesince, $inactivesince;
    }
    
    if ( defined($validemailavailable) && $validemailavailable eq 'yes' ) {
        push @where_strs, '(borrowers.email REGEXP \'^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]@[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]\.[a-zA-Z]{2,4}$\' OR '.
                           'borrowers.emailpro REGEXP \'^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]@[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]\.[a-zA-Z]{2,4}$\')';
    }
    if ( defined($validemailavailable) && $validemailavailable eq 'no' ) {
        push @where_strs, '(borrowers.email NOT REGEXP \'^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]@[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]\.[a-zA-Z]{2,4}$\' OR '.
                           'borrowers.email IS NULL) AND ' .
                           '(borrowers.emailpro NOT REGEXP \'^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]@[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]\.[a-zA-Z]{2,4}$\' OR ' .
                           'borrowers.emailpro IS NULL)';
    }
    if (defined($patronlistid) && $patronlistid =~ /^\d+$/ ) {
        push @where_strs, "EXISTS (SELECT 1 FROM  patron_list_patrons p WHERE p.patron_list_id = ? AND p.borrowernumber = borrowers.borrowernumber )";
        push @where_args, $patronlistid;
    }

    my $searchfields = {
        standard => C4::Context->preference('DefaultPatronSearchFields') || 'surname,firstname,othernames,cardnumber,userid,altcontactfirstname,altcontactsurname',
        surname => 'surname,altcontactsurname',
        email => 'email,emailpro,B_email',
        borrowernumber => 'borrowernumber',
        userid => 'userid',
        phone => 'phone,phonepro,B_phone,altcontactphone,mobile',
        address => 'streettype,address,address2,altcontactaddress1,altcontactaddress2,altcontactaddress3,altcontactzipcode,altcontactzipcode,city,state,zipcode,country',
        dateofbirth => 'dateofbirth',
        sort1 => 'sort1',
        sort2 => 'sort2',
        city => 'city',
    };

    # * is replaced with % for sql
    $searchmember =~ s/\*/%/g;

    # split into search terms
    my @terms;
    # consider coma as space
    $searchmember =~ s/,/ /g;
    if ( $searchtype eq 'contain' ) {
       @terms = split / /, $searchmember;
    } else {
       @terms = ($searchmember);
    }

    foreach my $term (@terms) {
        next unless $term;

        my $term_dt = eval { local $SIG{__WARN__} = {}; output_pref( { str => $term, dateonly => 1, dateformat => 'sql' } ); };

        if ($term_dt) {
            $term = $term_dt;
        } else {
            $term .= '%'    # end with anything
              if $term !~ /%$/;
            $term = "%$term"    # begin with anythin unless start_with
              if $searchtype eq 'contain' && $term !~ /^%/;
        }

        my @where_strs_or;
        for my $searchfield ( split /,/, $searchfields->{$searchfieldstype} ) {
            push @where_strs_or, "borrowers." . $dbh->quote_identifier($searchfield) . " LIKE ?";
            push @where_args, $term;
        }

        if ( $searchfieldstype eq 'standard' and C4::Context->preference('ExtendedPatronAttributes') and $searchmember ) {
            my $matching_borrowernumbers = C4::Members::Attributes::SearchIdMatchingAttribute($searchmember);

            for my $borrowernumber ( @$matching_borrowernumbers ) {
                push @where_strs_or, "borrowers.borrowernumber = ?";
                push @where_args, $borrowernumber;
            }
        }

        push @where_strs, '('. join (' OR ', @where_strs_or) . ')'
            if @where_strs_or;
    }

    my $where;
    $where = " WHERE " . join (" AND ", @where_strs) if @where_strs;
    my $orderby = dt_build_orderby($dt_params);

    my $limit;
    # If iDisplayLength == -1, we want to display all patrons
    if ( !$dt_params->{iDisplayLength} || $dt_params->{iDisplayLength} > -1 ) {
        # In order to avoid sql injection
        $dt_params->{iDisplayStart} =~ s/\D//g if defined($dt_params->{iDisplayStart});
        $dt_params->{iDisplayLength} =~ s/\D//g if defined($dt_params->{iDisplayLength});
        $dt_params->{iDisplayStart} //= 0;
        $dt_params->{iDisplayLength} //= 20;
        $limit = "LIMIT $dt_params->{iDisplayStart},$dt_params->{iDisplayLength}";
    }

    # Get and return information from borrower_attributes
    if ( $return_borrower_attributes ) {
        my @borrower_attributes_codes = split /,/, $return_borrower_attributes;
        my $select_borrower_attributes = '';
        my $from_borrower_attributes = '';
        #my $where_borrower_attributes = '';
        my $i = 0;
        foreach my $code (@borrower_attributes_codes) {
            $select_borrower_attributes .= " , ba$i.code as borr_attr_code_$code, ba$i.attribute as borr_attr_attribute_$code ";
            $from_borrower_attributes .= " LEFT JOIN borrower_attributes ba$i ON borrowers.borrowernumber = ba$i.borrowernumber AND ba$i.code = '$code' ";
            #$where_borrower_attributes .= " AND ba$i.code = ' $code ' ";
            $i += 1;
        }
        $select .= $select_borrower_attributes;
        $from .= $from_borrower_attributes;
        #$where .= $where_borrower_attributes;
    }

    $query = join(
        " ",
        ($select ? $select : ""),
        ($from ? $from : ""),
        ($where ? $where : ""),
        ($orderby ? $orderby : ""),
        ($limit ? $limit : "")
    );
    $sth = $dbh->prepare($query);
    $sth->execute(@where_args);
    my $patrons = $sth->fetchall_arrayref({});

    # Get the iTotalDisplayRecords DataTable variable
    $query = "SELECT COUNT(borrowers.borrowernumber) " . $from . ($where ? $where : "");
    $sth = $dbh->prepare($query);
    $sth->execute(@where_args);
    ($iTotalDisplayRecords) = $sth->fetchrow_array;

    # Get some information on patrons
    foreach my $patron (@$patrons) {
        my $patron_object = Koha::Patrons->find( $patron->{borrowernumber} );
        $patron->{overdues} = $patron_object->get_overdues->count;
        $patron->{issues} = $patron_object->checkouts->count;
        my $balance = $patron_object->account->balance;
        # FIXME Should be formatted from the template
        $patron->{fines} = sprintf("%.2f", $balance);

        if( $patron->{dateexpiry} ) {
            # FIXME We should not format the date here, do it in template-side instead
            $patron->{dateexpiry} = output_pref( { dt => scalar dt_from_string( $patron->{dateexpiry}, 'iso'), dateonly => 1} );
        } else {
            $patron->{dateexpiry} = '';
        }
    }

    return {
        iTotalRecords => $iTotalRecords,
        iTotalDisplayRecords => $iTotalDisplayRecords,
        patrons => $patrons
    }
}

1;
__END__

=head1 NAME

C4::Utils::DataTables::Members - module for using DataTables with patrons

=head1 SYNOPSIS

This module provides (one for the moment) routines used by the patrons search

=head2 FUNCTIONS

=head3 search

    my $dt_infos = C4::Utils::DataTables::Members->search($params);

$params is a hashref with some keys:

=over 4

=item searchmember

  String to search in the borrowers sql table

=item firstletter

  Introduced to contain 1 letter but can contain more.
  The search will done on the borrowers.surname field

=item categorycode

  Search patrons with this categorycode

=item branchcode

  Search patrons with this branchcode

=item searchtype

  Can be 'start_with' or 'contain' (default value). Used for the searchmember parameter.

=item searchfieldstype

  Can be 'standard' (default value), 'email', 'borrowernumber', 'phone', 'address' or 'dateofbirth', 'sort1', 'sort2'

=item dt_params

  Is the reference of C4::Utils::DataTables::dt_get_params($input);

=cut

=back

=head1 LICENSE

This file is part of Koha.

Copyright 2013 BibLibre
parts Copyright 2018 (C) LMSCLoud GmbH

Koha is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

Koha is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Koha; if not, see <http://www.gnu.org/licenses>.
