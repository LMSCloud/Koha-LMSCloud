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
use CGI qw ( -utf8 );
use C4::Context;
use C4::Output;
use C4::Auth;
use C4::Koha;
use C4::Letters;
use C4::Members;
use C4::Overdues;
use Koha::ClaimingRule;
use Koha::ClaimingRules;
use Koha::Libraries;

use Koha::Patron::Categories;

our $input = CGI->new;
my $dbh = C4::Context->dbh;

my @patron_categories = Koha::Patron::Categories->search( { overduenoticerequired => { '>' => 0 } } );
my @category_codes  = map { $_->categorycode } @patron_categories;

our @rule_params     = qw(delay letter debarred);

# blank_row($category_code) - return true if the entire row is blank.
sub blank_row {
    my ($category_code) = @_;
    for my $rp (@rule_params) {
        for my $n (1 .. 5) {
            my $key   = "${rp}${n}-$category_code";

            if (utf8::is_utf8($key)) {
              utf8::encode($key);
            }

            my $value = $input->param($key);
            if ($value) {
                return 0;
            }
        }
    }
    return 1;
}

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/overduerules.tt",
        query           => $input,
        type            => "intranet",
        flagsrequired   => { tools => 'edit_notice_status_triggers' },
        debug           => 1,
    }
);

my $branch = $input->param('branch');
$branch =
    defined $branch                                                    ? $branch
  : C4::Context->preference('DefaultToLoggedInLibraryOverdueTriggers') ? C4::Context::mybranch()
  : Koha::Libraries->search->count() == 1                              ? undef
  :                                                                      undef;
$branch ||= q{};

my $op = $input->param('op');
$op ||= q{};

my $language = C4::Languages::getlanguage();

my $err=0;

# save the values entered into tables
my %temphash;
my $input_saved = 0;
if ($op eq 'save') {
    my $type = $input->param('type');
    my @names=$input->multi_param();
    my $sth_search = $dbh->prepare("SELECT count(*) AS total FROM overduerules WHERE branchcode=? AND categorycode=?");

    my $sth_insert = $dbh->prepare("INSERT INTO overduerules (branchcode,categorycode, delay1,letter1,debarred1, delay2,letter2,debarred2, delay3,letter3,debarred3, delay4,letter4,debarred4, delay5,letter5,debarred5 ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
    my $sth_update=$dbh->prepare("UPDATE overduerules SET delay1=?, letter1=?, debarred1=?, delay2=?, letter2=?, debarred2=?, delay3=?, letter3=?, debarred3=?, delay4=?, letter4=?, debarred4=?, delay5=?, letter5=?, debarred5=? WHERE branchcode=? AND categorycode=?");
    my $sth_delete=$dbh->prepare("DELETE FROM overduerules WHERE branchcode=? AND categorycode=?");
    my $sth_insert_mtt = $dbh->prepare("
        INSERT INTO overduerules_transport_types(
            overduerules_id, letternumber, message_transport_type
        ) VALUES (
            (SELECT overduerules_id FROM overduerules WHERE branchcode = ? AND categorycode = ?), ?, ?
        )
    ");
    my $sth_delete_mtt = $dbh->prepare("
        DELETE FROM overduerules_transport_types
        WHERE overduerules_id = (SELECT overduerules_id FROM overduerules WHERE branchcode = ? AND categorycode = ?)
    ");

    foreach my $key (@names){
            # ISSUES
            if ($key =~ /(delay|letter|debarred)([1-5])-(.*)/) {
                    my $type = $1; # data type
                    my $num = $2; # From 1 to 3
                    my $bor = $3; # borrower category
                    my $value = $input->param($key);
                    if ($type eq 'delay') {
                        $temphash{$bor}->{"$type$num"} = ($value =~ /^\d+$/ && int($value) > 0) ? int($value) : '';
                    }
                    else {
                        # type is letter
                        $temphash{$bor}->{"$type$num"} = $value if $value ne '';
                    }
            }
    }

    # figure out which rows need to be deleted
    my @rows_to_delete = grep { blank_row($_) } @category_codes;

    foreach my $bor (keys %temphash){
        # get category name if we need it for an error message
        my $bor_category = Koha::Patron::Categories->find($bor);
        my $bor_category_name = $bor_category ? $bor_category->description : $bor;

        # Do some Checking here : delay1 < delay2 <delay3 all of them being numbers
        # Raise error if not true
        if ($temphash{$bor}->{delay1}=~/[^0-9]/ and $temphash{$bor}->{delay1} ne ""){
            $template->param("ERROR"=>1,"ERRORDELAY"=>"delay1","BORERR"=>$bor_category_name);
            $err=1;
        } elsif ($temphash{$bor}->{delay2}=~/[^0-9]/ and $temphash{$bor}->{delay2} ne ""){
            $template->param("ERROR"=>1,"ERRORDELAY"=>"delay2","BORERR"=>$bor_category_name);
            $err=1;
        } elsif ($temphash{$bor}->{delay3}=~/[^0-9]/ and $temphash{$bor}->{delay3} ne ""){
            $template->param("ERROR"=>1,"ERRORDELAY"=>"delay3","BORERR"=>$bor_category_name);
            $err=1;
        } elsif ($temphash{$bor}->{delay4}=~/[^0-9]/ and $temphash{$bor}->{delay4} ne ""){
            $template->param("ERROR"=>1,"ERRORDELAY"=>"delay4","BORERR"=>$bor_category_name);
            $err=1;
        } elsif ($temphash{$bor}->{delay5}=~/[^0-9]/ and $temphash{$bor}->{delay5} ne ""){
            $template->param("ERROR"=>1,"ERRORDELAY"=>"delay5","BORERR"=>$bor_category_name);
            $err=1;
        } elsif ($temphash{$bor}->{delay1} and not ($temphash{$bor}->{"letter1"} or $temphash{$bor}->{"debarred1"})) {
            $template->param("ERROR"=>1,"ERRORUSELESSDELAY"=>"delay1","BORERR"=>$bor_category_name);
            $err=1;
        } elsif ($temphash{$bor}->{delay2} and not ($temphash{$bor}->{"letter2"} or $temphash{$bor}->{"debarred2"})) {
            $template->param("ERROR"=>1,"ERRORUSELESSDELAY"=>"delay2","BORERR"=>$bor_category_name);
            $err=1;
        } elsif ($temphash{$bor}->{delay3} and not ($temphash{$bor}->{"letter3"} or $temphash{$bor}->{"debarred3"})) {
            $template->param("ERROR"=>1,"ERRORUSELESSDELAY"=>"delay3","BORERR"=>$bor_category_name);
            $err=1;
        } elsif ($temphash{$bor}->{delay4} and not ($temphash{$bor}->{"letter4"} or $temphash{$bor}->{"debarred4"})) {
            $template->param("ERROR"=>1,"ERRORUSELESSDELAY"=>"delay4","BORERR"=>$bor_category_name);
            $err=1;
        } elsif ($temphash{$bor}->{delay5} and not ($temphash{$bor}->{"letter5"} or $temphash{$bor}->{"debarred5"})) {
            $template->param("ERROR"=>1,"ERRORUSELESSDELAY"=>"delay5","BORERR"=>$bor_category_name);
            $err=1;
        } 
        unless ($err) {
            CHKDELAY: for (my $i=5;$i>1;$i--) {
                if ( $temphash{$bor}->{'delay'.$i} ) {
                    for (my $j=$i-1;$j>=1;$j--) {
                        if ( (! $temphash{$bor}->{'delay'.$j}) or  $temphash{$bor}->{'delay'.$i}<= $temphash{$bor}->{'delay'.$j} ) {
                            $template->param("ERROR"=>1,"ERRORORDER"=>1,"BORERR"=>$bor_category_name);
                            $err=1;
                            last CHKDELAY;
                        }
                    }
                }
            }
        }
        unless ($err){
            if (($temphash{$bor}->{delay1} and ($temphash{$bor}->{"letter1"} or $temphash{$bor}->{"debarred1"}))
                or ($temphash{$bor}->{delay2} and ($temphash{$bor}->{"letter2"} or $temphash{$bor}->{"debarred2"}))
                or ($temphash{$bor}->{delay3} and ($temphash{$bor}->{"letter3"} or $temphash{$bor}->{"debarred3"}))
                or ($temphash{$bor}->{delay4} and ($temphash{$bor}->{"letter4"} or $temphash{$bor}->{"debarred4"}))
                or ($temphash{$bor}->{delay5} and ($temphash{$bor}->{"letter5"} or $temphash{$bor}->{"debarred5"}))
                ) {
                    $sth_search->execute($branch,$bor);
                    my $res = $sth_search->fetchrow_hashref();
                    if ($res->{'total'}>0) {
                        $sth_update->execute(
                            ($temphash{$bor}->{"delay1"}?$temphash{$bor}->{"delay1"}:undef),
                            ($temphash{$bor}->{"letter1"}?$temphash{$bor}->{"letter1"}:""),
                            ($temphash{$bor}->{"debarred1"}?$temphash{$bor}->{"debarred1"}:0),
                            ($temphash{$bor}->{"delay2"}?$temphash{$bor}->{"delay2"}:undef),
                            ($temphash{$bor}->{"letter2"}?$temphash{$bor}->{"letter2"}:""),
                            ($temphash{$bor}->{"debarred2"}?$temphash{$bor}->{"debarred2"}:0),
                            ($temphash{$bor}->{"delay3"}?$temphash{$bor}->{"delay3"}:undef),
                            ($temphash{$bor}->{"letter3"}?$temphash{$bor}->{"letter3"}:""),
                            ($temphash{$bor}->{"debarred3"}?$temphash{$bor}->{"debarred3"}:0),
                            ($temphash{$bor}->{"delay4"}?$temphash{$bor}->{"delay4"}:undef),
                            ($temphash{$bor}->{"letter4"}?$temphash{$bor}->{"letter4"}:""),
                            ($temphash{$bor}->{"debarred4"}?$temphash{$bor}->{"debarred4"}:0),
                            ($temphash{$bor}->{"delay5"}?$temphash{$bor}->{"delay5"}:undef),
                            ($temphash{$bor}->{"letter5"}?$temphash{$bor}->{"letter5"}:""),
                            ($temphash{$bor}->{"debarred5"}?$temphash{$bor}->{"debarred5"}:0),
                            $branch ,$bor
                            );
                    } else {
                        $sth_insert->execute($branch,$bor,
                            ($temphash{$bor}->{"delay1"}?$temphash{$bor}->{"delay1"}:0),
                            ($temphash{$bor}->{"letter1"}?$temphash{$bor}->{"letter1"}:""),
                            ($temphash{$bor}->{"debarred1"}?$temphash{$bor}->{"debarred1"}:0),
                            ($temphash{$bor}->{"delay2"}?$temphash{$bor}->{"delay2"}:0),
                            ($temphash{$bor}->{"letter2"}?$temphash{$bor}->{"letter2"}:""),
                            ($temphash{$bor}->{"debarred2"}?$temphash{$bor}->{"debarred2"}:0),
                            ($temphash{$bor}->{"delay3"}?$temphash{$bor}->{"delay3"}:0),
                            ($temphash{$bor}->{"letter3"}?$temphash{$bor}->{"letter3"}:""),
                            ($temphash{$bor}->{"debarred3"}?$temphash{$bor}->{"debarred3"}:0),
                            ($temphash{$bor}->{"delay4"}?$temphash{$bor}->{"delay4"}:0),
                            ($temphash{$bor}->{"letter4"}?$temphash{$bor}->{"letter4"}:""),
                            ($temphash{$bor}->{"debarred4"}?$temphash{$bor}->{"debarred4"}:0),
                            ($temphash{$bor}->{"delay5"}?$temphash{$bor}->{"delay5"}:0),
                            ($temphash{$bor}->{"letter5"}?$temphash{$bor}->{"letter5"}:""),
                            ($temphash{$bor}->{"debarred5"}?$temphash{$bor}->{"debarred5"}:0)
                            );
                    }

                    $sth_delete_mtt->execute( $branch, $bor );
                    for my $letternumber ( 1..5 ) {
                        my @mtt = $input->multi_param( "mtt${letternumber}-$bor" );
                        next unless @mtt;
                        for my $mtt ( @mtt ) {
                            $sth_insert_mtt->execute( $branch, $bor, $letternumber, $mtt);
                        }
                    }
                }
        }
    }
    unless ($err) {
        for my $category_code (@rows_to_delete) {
            $sth_delete->execute($branch, $category_code);
        }
        $template->param(datasaved => 1);
        $input_saved = 1;
    }
}
# delete a new claiming fee rule
elsif ($op eq 'deleteRule') {
    my $itemtype     = $input->param('itemtype');
    my $categorycode = $input->param('categorycode');

    my $sth_Idelete = $dbh->prepare("delete from claiming_rules where branchcode=? and categorycode=? and itemtype=?");
    $sth_Idelete->execute($branch, $categorycode, $itemtype);
}
# add a new claiming fee rule
elsif ($op eq 'addRule') {
    my $branchcode = $branch; # branch
    if (! $branchcode || $branchcode eq '' ) {
        $branchcode = '*';
    }
    my $categorycode  = $input->param('categorycode'); # borrower category
    my $itemtype      = $input->param('itemtype');     # item type

    my $claim_fee_level1  = $input->param('claim_fee_level1');
    my $claim_fee_level2  = $input->param('claim_fee_level2');
    my $claim_fee_level3  = $input->param('claim_fee_level3');
    my $claim_fee_level4  = $input->param('claim_fee_level4');
    my $claim_fee_level5  = $input->param('claim_fee_level5');
    
    my $params = {
        'branchcode'        => $branchcode,
        'categorycode'      => $categorycode,
        'itemtype'          => $itemtype,
        'claim_fee_level1'  => $claim_fee_level1,
        'claim_fee_level2'  => $claim_fee_level2,
        'claim_fee_level3'  => $claim_fee_level3,
        'claim_fee_level4'  => $claim_fee_level4,
        'claim_fee_level5'  => $claim_fee_level5,
    };
    
    my @pnames = (
                    'claim_fee_level1',
                    'claim_fee_level2',
                    'claim_fee_level3',
                    'claim_fee_level4',
                    'claim_fee_level5',
                  );
    foreach my $param (@pnames) {
        if ( defined($params->{$param}) && $params->{$param} == 0 ) {
            $params->{$param} = undef;
        }
    }

    my $claimrule = Koha::ClaimingRules->find({categorycode => $categorycode, itemtype => $itemtype, branchcode => $branchcode});
    if ($claimrule) {
        $claimrule->set($params)->store();
    } else {
        $claimrule = Koha::ClaimingRule->new();
        $claimrule->set($params);
        $claimrule->store();
    }
}
# clone claiming fee rules
elsif ( $op eq 'cloneRules') {
    
    # read from branch
    my $frombranch  = $input->param('frombranch');
    $frombranch = '*' if ( $frombranch eq '' );
    
    # read to branch
    my $tobranch  = $input->param('tobranch');     # item type
    
    if ($frombranch && $tobranch && $frombranch ne $tobranch ) 
    {
        cloneClaimingRules($frombranch,$tobranch);
        $branch = $tobranch;
    }
}

########################################
#  Read avaliable letters
########################################
my $letters = C4::Letters::GetLettersAvailableForALibrary(
    {
        branchcode => $branch,
        module => "circulation",
    }
);

my $message_transport_types = C4::Letters::GetMessageTransportTypes();
my ( @first, @second, @third, @fourth, @fifth );
for my $patron_category (@patron_categories) {
    if (%temphash and not $input_saved){
        # if we managed to save the form submission, don't
        # reuse %temphash, but take the values from the
        # database - this makes it easier to identify
        # bugs where the form submission was not correctly saved
        for my $i ( 1..5 ){
            my %row = (
                overduename => $patron_category->categorycode,
                line        => $patron_category->description,
            );
            $row{delay}=$temphash{$patron_category->categorycode}->{"delay$i"};
            $row{debarred}=$temphash{$patron_category->categorycode}->{"debarred$i"};
            $row{selected_lettercode} = $temphash{ $patron_category->categorycode }->{"letter$i"};
            my @selected_mtts = @{ GetOverdueMessageTransportTypes( $branch, $patron_category->categorycode, $i) };
            my @mtts;
            for my $mtt ( @$message_transport_types ) {
                push @mtts, {
                    value => $mtt,
                    selected => ( grep {/$mtt/} @selected_mtts ) ? 1 : 0 ,
                }
            }
            $row{message_transport_types} = \@mtts;
            if ( $i == 1 ) {
                push @first, \%row;
            } elsif ( $i == 2 ) {
                push @second, \%row;
            } elsif ( $i == 3 ) {
                push @third, \%row;
            } elsif ( $i == 4 ) {
                push @fourth, \%row;
            } elsif ( $i == 5 ) {
                push @fifth, \%row;
            }
        }
    } else {
    #getting values from table
        my $sth2=$dbh->prepare("SELECT * from overduerules WHERE branchcode=? AND categorycode=?");
        $sth2->execute($branch,$patron_category->categorycode);
        my $dat=$sth2->fetchrow_hashref;
        for my $i ( 1..5 ){
            my %row = (
                overduename => $patron_category->categorycode,
                line        => $patron_category->description,
            );

            $row{selected_lettercode} = $dat->{"letter$i"};

            if ($dat->{"delay$i"}){$row{delay}=$dat->{"delay$i"};}
            if ($dat->{"debarred$i"}){$row{debarred}=$dat->{"debarred$i"};}
            my @selected_mtts = @{ GetOverdueMessageTransportTypes( $branch, $patron_category->categorycode, $i) };
            my @mtts;
            for my $mtt ( @$message_transport_types ) {
                push @mtts, {
                    value => $mtt,
                    selected => ( grep {/$mtt/} @selected_mtts ) ? 1 : 0 ,
                }
            }
            $row{message_transport_types} = \@mtts;
            if ( $i == 1 ) {
                push @first, \%row;
            } elsif ( $i == 2 ) {
                push @second, \%row;
            } elsif ( $i == 3 ) {
                push @third, \%row;
            } elsif ( $i == 4 ) {
                push @fourth, \%row;
            } elsif ( $i == 5 ) {
                push @fifth, \%row;
            }

        }
    }
}

my @tabs = (
    {
        id => 'first',
        number => 1,
        values => \@first,
    },
    {
        id => 'second',
        number => 2,
        values => \@second,
    },
    {
        id => 'third',
        number => 3,
        values => \@third,
    },
    {
        id => 'fourth',
        number => 4,
        values => \@fourth,
    },
    {
        id => 'fifth',
        number => 5,
        values => \@fifth,
    },
);


########################################
#  Read item types
########################################
my @itemtypes = Koha::ItemTypes->search_with_localization;

########################################
#  Read claiming fee rules 
########################################
my @claimingFeeRules = readClaimingRules($dbh, $branch, $language);


########################################
#  Set template paramater
########################################
$template->param(
                        categoryloop => \@patron_categories,
                        itemtypeloop => \@itemtypes,
                        rules => \@claimingFeeRules,
                        current_branch => $branch,
                        definedbranch => scalar(@claimingFeeRules)>0,
                        table => ( @first or @second or @third or @fourth or @fifth ? 1 : 0 ),
                        branch => $branch,
                        tabs => \@tabs,
                        message_transport_types => $message_transport_types,
                        letters => $letters
);
output_html_with_http_headers $input, $cookie, $template->output;

########################################
#  Function for read claiming fee rules 
########################################
sub readClaimingRules {
    my $dbh = shift;
    my $branch = shift;
    my $language = shift;
    my @claiming_rules;
    my $query =
        qq{ SELECT  claiming_rules.*,
                itemtypes.description AS humanitemtype,
                categories.description AS humancategorycode,
                COALESCE( localization.translation, itemtypes.description ) AS translated_description
            FROM claiming_rules
                LEFT JOIN itemtypes ON (itemtypes.itemtype = claiming_rules.itemtype)
                LEFT JOIN categories ON (categories.categorycode = claiming_rules.categorycode)
                LEFT JOIN localization ON claiming_rules.itemtype = localization.code
                     AND localization.entity = 'itemtypes' 
                     AND localization.lang = ?
            WHERE claiming_rules.branchcode = ? }; $query =~ s/^\s*/ /mg;
    my $read_rules_sth = $dbh->prepare($query);
    $read_rules_sth->execute($language, $branch eq '' ? '*' : $branch);

    while (my $row = $read_rules_sth->fetchrow_hashref) {
        $row->{'current_branch'}  ||= $row->{'branchcode'};
        $row->{'humanitemtype'}   ||= $row->{itemtype};
        $row->{'default_translated_description'} = 1 if $row->{humanitemtype} eq '*';
        $row->{'humancategorycode'} ||= $row->{'categorycode'};
        $row->{'default_humancategorycode'} = 1 if $row->{'humancategorycode'} eq '*';
        
        $row->{'claim_fee_level1'} = sprintf('%.2f', $row->{'claim_fee_level1'} || 0.0 );
        $row->{'claim_fee_level2'} = sprintf('%.2f', $row->{'claim_fee_level2'} || 0.0 );
        $row->{'claim_fee_level3'} = sprintf('%.2f', $row->{'claim_fee_level3'} || 0.0 );
        $row->{'claim_fee_level4'} = sprintf('%.2f', $row->{'claim_fee_level4'} || 0.0 );
        $row->{'claim_fee_level5'} = sprintf('%.2f', $row->{'claim_fee_level5'} || 0.0 );
        
        push @claiming_rules, $row;
    }

    $read_rules_sth->finish;

    # now sort the rules
    my @sorted_claiming_rules = sort by_category_and_itemtype @claiming_rules;
    # sort by patron category, then item type, putting
    # default entries at the bottom
    sub by_category_and_itemtype {
        unless (by_category($a, $b)) {
            return by_itemtype($a, $b);
        }
    }
    
    return @sorted_claiming_rules;
}

sub by_category {
    my ($a, $b) = @_;
    if ($a->{'default_humancategorycode'}) {
        return ($b->{'default_humancategorycode'} ? 0 : 1);
    } elsif ($b->{'default_humancategorycode'}) {
        return -1;
    } else {
        return $a->{'humancategorycode'} cmp $b->{'humancategorycode'};
    }
}

sub by_itemtype {
    my ($a, $b) = @_;
    if ($a->{default_translated_description}) {
        return ($b->{'default_translated_description'} ? 0 : 1);
    } elsif ($b->{'default_translated_description'}) {
        return -1;
    } else {
        return lc $a->{'translated_description'} cmp lc $b->{'translated_description'};
    }
}

########################################
#  Clone claiming fee rules for branches
########################################
sub cloneClaimingRules {
    my $fromBranch = shift;
    my $toBranch = shift;
    
    my %existingRules =();
    
    # read the claiming rules for further processing
    
    my $copyrules = Koha::ClaimingRules->search({ branchcode => $fromBranch });
    # put in a hash the aready existing values
    # it's used to determine which rules of the target branch need to be deleted
    while ( my $rule = $copyrules->next() ) {
        $existingRules{$rule->categorycode() ."\t".$rule->itemtype()} = 1;
    }
    
    # read the claiming rules for further processing and 
    # delete already existing rules with the same patron type and item type
    my $deleterules = Koha::ClaimingRules->search({ 'branchcode' => $toBranch });
    while ( my $rule = $deleterules->next() ) {
        if ( exists($existingRules{$rule->categorycode() ."\t".$rule->itemtype()}) ) {
            $rule->delete();
        }
    }
    
    # read through the rules again and create copies with the branch
    $copyrules->reset();
    while ( my $rule = $copyrules->next() ) {
        my $newrule = Koha::ClaimingRule->new( {
		branchcode       => $toBranch,
		categorycode     => $rule->categorycode(),
		itemtype         => $rule->itemtype(),
		claim_fee_level1 => $rule->claim_fee_level1(),
		claim_fee_level2 => $rule->claim_fee_level2(),
		claim_fee_level3 => $rule->claim_fee_level3(),
		claim_fee_level4 => $rule->claim_fee_level4(),
		claim_fee_level5 => $rule->claim_fee_level5(),
        } );
        $newrule->store();
    }
}


exit 0;

