#!/usr/bin/perl

# Copyright 2016 LMSCLoud GmbH
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
use CGI qw ( -utf8 );
use C4::Context;
use C4::Output;
use C4::Auth;
use C4::Koha;
use C4::Letters;
use Koha::NoticeFeeRule;
use Koha::NoticeFeeRules;
use Koha::Libraries;

our $input = new CGI;
my $dbh = C4::Context->dbh;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/notice-fee-rules.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { tools => 'edit_notice_fee_rules' },
        debug           => 1,
    }
);

my $branch = $input->param('branch');
$branch =
    defined $branch                                                    ? $branch
  : C4::Context->preference('DefaultToLoggedInLibraryOverdueTriggers') ? C4::Branch::mybranch()
  : Koha::Libraries->search->count() == 1                              ? undef
  :                                                                      undef;
$branch ||= q{};
$branch = q{} if $branch eq 'NO_LIBRARY_SET';

my $op = $input->param('op');
$op ||= q{};

########################################
#  Process the request
########################################
if ($op eq 'deleteRule') {
    my $categorycode           = $input->param('categorycode');
    my $message_transport_type = $input->param('message_transport_type');
    my $letter_code            = $input->param('letter_code');

    my $rules = Koha::NoticeFeeRules->search({ 
        branchcode => $branch, 
        categorycode => $categorycode, 
        message_transport_type => $message_transport_type, 
        letter_code => $letter_code 
    });
    while ( my $rule = $rules->next() ) {
        $rule->delete();
    }
}
# add a new notice fee rule
elsif ($op eq 'addRule') {
    my $params = {};
    $params->{branchcode}             = $branch;
    $params->{branchcode}             = '*' if ( !$branch || $branch eq '');
    $params->{categorycode}           = $input->param('categorycode');
    $params->{message_transport_type} = $input->param('message_transport_type');
    $params->{letter_code}            = $input->param('letter_code');
    $params->{notice_fee}             = $input->param('notice_fee');

    my $rule = Koha::NoticeFeeRules->find({ 
        branchcode => $params->{branchcode}, 
        categorycode => $params->{categorycode}, 
        message_transport_type => $params->{message_transport_type}, 
        letter_code => $params->{letter_code}
    });
    if ($rule) {
        $rule->set($params)->store();
    } else {
        $rule = Koha::NoticeFeeRule->new();
        $rule->set($params);
        $rule->store();
    }
}
# clone notice fee rules
elsif ( $op eq 'cloneRules') {
    
    # read from branch
    my $frombranch  = $input->param('frombranch');
    $frombranch = '*' if ( $frombranch eq '' );
    
    # read to branch
    my $tobranch  = $input->param('tobranch');     # item type
    
    if ($frombranch && $tobranch && $frombranch ne $tobranch ) 
    {
        cloneNoticeFeeRules($frombranch,$tobranch);
        $branch = $tobranch;
    }
}

########################################
#  Read borrower categories
########################################
my @categories = @{$dbh->selectall_arrayref(
    'SELECT description, categorycode FROM categories ORDER BY description',
    { Slice => {} }
)};


########################################
#  Read avaliable letters
########################################
# these are the moduls and letter codes that we allow
my @moduleletters = (
    { module => 'circulation', matchcodes => 'ODUE.*'}, # we might add later messages for advance notices like: DUE|DUEDGST|PREDUE|PREDUEDGST
    { module => 'circulation', matchcodes => 'FINES_DUE.*'},
    { module => 'members',     matchcodes => 'FINES_DUE.*'},
    { module => 'reserves',    matchcodes => 'HOLD'},
    { module => 'circulation', matchcodes => '.*_CHARGE'},
    { module => 'members',     matchcodes => '.*_CHARGE'}
);
my $letters = [];
foreach my $modulelettercfg (@moduleletters) {
    my $selectletters = C4::Letters::GetLettersAvailableForALibrary(
        {
            branchcode => $branch,
            module => $modulelettercfg->{module}
        }
    );
    foreach my $letter (@$selectletters) {
        if ( $letter->{code} =~ /^($modulelettercfg->{matchcodes})$/ ) {
            push(@$letters,$letter);
        }
    }
}
my @sorted_letters = sort { uc($a->{name}) cmp uc($b->{name}) } @$letters;
$letters = \@sorted_letters;

########################################
#  Read notice fee rules 
########################################
my @noticeFeeRules = readNoticeFeeRules($dbh,$branch);


########################################
#  Read message transport types
########################################
my @line_loop;
my $message_transport_types = C4::Letters::GetMessageTransportTypes();


########################################
#  Set template paramater
########################################
$template->param(
                        categoryloop => \@categories,
                        rules => \@noticeFeeRules,
                        definedbranch => scalar(@noticeFeeRules)>0,
                        branch => $branch,
                        message_transport_types => $message_transport_types,
                        letters => $letters
);
output_html_with_http_headers $input, $cookie, $template->output;

########################################
#  Function for reading notice fee rules 
########################################
sub readNoticeFeeRules {
    my $dbh = shift;
    my $branch = shift;
    my @notice_fee_rules;
    my $query =
        qq{ SELECT  notice_fee_rules.*,
                categories.description AS humancategorycode
            FROM notice_fee_rules
                LEFT JOIN categories ON (categories.categorycode = notice_fee_rules.categorycode)
            WHERE notice_fee_rules.branchcode = ? }; $query =~ s/^\s*/ /mg;
    
    my $read_rules_sth = $dbh->prepare($query);
    $read_rules_sth->execute($branch eq '' ? '*' : $branch);

    while (my $row = $read_rules_sth->fetchrow_hashref) {
        $row->{'current_branch'}          ||= $row->{'branchcode'};
        $row->{'categorycode'}            ||= $row->{'categorycode'};
        $row->{'humancategorycode'}       ||= $row->{'categorycode'};
        $row->{'default_humancategorycode'} = 1 if $row->{'humancategorycode'} eq '*';
        $row->{'message_transport_type'}  ||= $row->{'message_transport_type'};
        $row->{'letter_code'}             ||= $row->{'letter_code'}; 
        
        $row->{'notice_fee'}                = sprintf('%.2f', $row->{'notice_fee'} || 0.0 );
        
        push @notice_fee_rules, $row;
    }

    $read_rules_sth->finish;

    # now sort the rules
    my @sorted_notice_fee_rules = sort by_category_and_transport_type_and_letter @notice_fee_rules;
    # sort by patron category, then item type, putting
    # default entries at the bottom
    sub by_category_and_transport_type_and_letter {
        unless (by_crit($a, $b,'humancategorycode')) {
            unless (by_crit($a, $b, 'letter_code')) {
                return by_crit($a, $b, 'message_transport_type');
            }
        }
    }
    
    return @sorted_notice_fee_rules;
}

sub by_crit {
    my ($a, $b, $crit) = @_;
    if ( $a && $b ) {
        if ( $a->{$crit} && $b->{$crit} ) {
            if ( $a->{$crit} eq '*') {
                return (($b->{$crit} eq '*') ? 0 : 1);
            }
            return -1 if ( $b->{$crit} eq '*');
            
           return (uc($a->{$crit}) cmp uc($b->{$crit}));
        }
        return -1 if ( $b->{$crit} );
        return 1 if ( $a->{$crit} );
        return 0;
    }
    return -1 if ( $b );
    return 1 if ( $a );
    return 0;
}

########################################
#  Clone notice fee rules for branches
########################################
sub cloneNoticeFeeRules {
    my $fromBranch = shift;
    my $toBranch = shift;
    
    my %existingRules =();
    
    my $copyrules = Koha::NoticeFeeRules->search({ branchcode => $fromBranch });
    # put in a hash the aready existing values
    # it's used to determine which rules of the target branch need to be deleted
    while ( my $rule = $copyrules->next() ) {
        $existingRules{$rule->categorycode() ."\t".$rule->message_transport_type()."\t".$rule->letter_code()} = 1;
    }
    
    # read the notice fee rules for further processing and 
    # delete already existing rules with the same patron type and item type
    my $deleterules = Koha::NoticeFeeRules->search({ 'branchcode' => $toBranch });
    while ( my $rule = $deleterules->next() ) {
        if ( exists($existingRules{$rule->categorycode() ."\t".$rule->message_transport_type()."\t".$rule->letter_code()}) ) {
            $rule->delete();
        }
    }
    
    # read through the rules again and create copies with the branch
    $copyrules->reset();
    while ( my $rule = $copyrules->next() ) {
        my $newrule = Koha::NoticeFeeRule->new( {
		branchcode             => $toBranch,
		categorycode           => $rule->categorycode(),
		message_transport_type => $rule->message_transport_type(),
		letter_code            => $rule->letter_code(),
		notice_fee             => $rule->notice_fee()
        } );
        $newrule->store();
    }
}

exit 0;

