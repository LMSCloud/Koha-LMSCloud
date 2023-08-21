package C4::ClaimingFees;

# Copyright LMCloud GmbH 2016
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

use strict;
use warnings;

use Date::Calc qw/Today Date_to_Days/;
use Locale::Currency::Format;
use Carp;

use Koha::ClaimingRule;
use Koha::ClaimingRules;
use Koha::Account::Line;
use Koha::Account::Lines;
use Koha::Account::Offset;
use Koha::DateUtils qw( output_pref dt_from_string );
use Koha::Notice::Templates;
use C4::Log; # logaction
use C4::Letters;
use C4::Overdues;
use Koha::Acquisition::Currencies;

use vars qw(@ISA @EXPORT);

BEGIN {
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw();
}


=head1 NAME

C4::ClaimingFees - Koha module to charge claiming fees 

=head1 SYNOPSIS

 use Koha::ClaimingRules;
 use Koha::ClaimingRule;

  my $claimFeeRule = $claimFees->getFittingClaimingRule($categorycode,$itemtype,$branchcode);
  if ( $claimFeeRule ) {
     $fee = $claimFeeRule->claim_fee_level2;
     if ( $fee && $fee > 0.0 ) {
         $claimFees->AddClaimFee({
             issue_id       => $item->{'issue_id'},
             itemnumber     => $item->{'itemnumber'},
             borrowernumber => $item->{'borrowernumber'},
             amount         => $fee,
             due            => $item->{date_due},
             claimlevel     => 2,
             due_since_days => 20, # 20 days
             branchcode     => $branchcode
         });
      }
  }

=head1 DESCRIPTION

The module is used to calculate overdue/claim fines for items that are overdue.
A major differences between claim fees and fines defined with the issuerules
are the following:
- Claim fees allocated when an overdue reminder is been created for an item
- A claim fee can be different for each reminder level from 1 to 5
- Claim fees are charged per reminder per item
In comparison an overdue fine as defined with the issue rules will is charged 
based on a defined frequency with the same amount continuously.

It uses the confguration stored with claiming fee rules. A claiming fee rule
specifies claiming fees for up to 5 reminder levels depending on branch library, 
patron group, and item type.

Multiple claiming rules can overload each other with a more specific setting.
This module loads with the new function the existing claiming rules. After 
initialization, the C4::ClaimingFees object can be used to deliver a matching
rule for an existing combination of borrower category, branchcode and item type.

If a rule matches, the module provides a function to add an amount for an
overdue item according to the claiming level.

=head1 FUNCTIONS

=head2 new

  C4::ClaimingFees->new()

Creates a new C4::ClaimingFees. During initialization, the defined claiming fee 
rules of the instance are read. 

Returns a reference to the object.

=cut
sub new {
    my $class = shift;
    my $self  = bless { @_ }, $class;
    
    
    # read the claiming rules for further processing
    my $claimingrules = Koha::ClaimingRules->search({});
    
    my $rules = {};
    
    my $rules_count = 0;
    
    # assign a hash of hashes of hashes for fast checks whether a claiming rule first or not
    while ( my $rule = $claimingrules->next() ) {
        $rules->{$rule->branchcode()}->{$rule->categorycode()}->{$rule->itemtype()} = $rule;
        $rules_count++;
    }
    
    # leave it with the object data
    $self->{'rules'} = $rules;
    $self->{'rules_count'} = $rules_count;

    return $self;
}



=head2 checkForClaimingRules

  $zeroOrOne = $claimfees->checkForClaimingRules();

Returns whether there are claiming fee rules defined. Returns 0 for no and 1 for yes.

=cut

sub checkForClaimingRules {
    my $self = shift;
    
    return 1 if ( $self->{'rules_count'} > 0 );
    return 0;
}

=head2 getFittingClaimingRule

  $rule = $claimfees->getFittingClaimingRule($borrowertype, $itemtype, $branchcode ) ;

Checks whether the is a matching claim fee rule for a combination of the three values
borrower type, item type and branchcode.

=cut

sub getFittingClaimingRule {
    my ( $self, $borrowertype, $itemtype, $branchcode ) = @_;
    
    return undef if ( $self->{'rules_count'} == 0 );
    
    my $rules =  $self->{'rules'};
    
    my @chkrules;
    # We create an array of checks to process in order to find the best fitting rule.
    # A more specific rule fits better than a general rule.
    #
    # The rules are applied from most specific to less specific, using the first found in this order:
    # same library, same patron type, same item type
    # same library, same patron type, all item types
    # same library, all patron types, same item type
    # same library, all patron types, all item types
    # default (all libraries), same patron type, same item type
    # default (all libraries), same patron type, all item types
    # default (all libraries), all patron types, same item type
    # default (all libraries), all patron types, all item types

    foreach my $x ( ($branchcode,'*') ) {
        foreach my $y ( ($borrowertype,'*') ) {
            foreach my $z ( ($itemtype,'*') ) {
                push @chkrules, [$x,$y,$z];
            }
        }
    }
    
    # Now we process the checks against the hash that we have build during object initialization
    foreach my $chkrule (@chkrules) {
        if (    exists( $rules->{$chkrule->[0]}) &&  # compare the library
		exists( $rules->{$chkrule->[0]}->{$chkrule->[1]}) &&  # compare type 
		exists( $rules->{$chkrule->[0]}->{$chkrule->[1]}->{$chkrule->[2]} ) # compare item type
	)
	{
	    # if found return the rule
	    return $rules->{$chkrule->[0]}->{$chkrule->[1]}->{$chkrule->[2]};
	}
    }
    return undef;
}

=head2 AddClaimFee

  $claimfees->AddClaimFee($params) ;

Charges a claim fee to a borrower. The fee is added to the account of the borrower.
The function takes a hash reference as parameter. The hash ref is required to provide
the following data:

  $params->{branchcode}       # string: set the code of the branch
  $params->{issue_id}         # integer: id of the issue
  $params->{itemnumber}       # integer: itemnumber
  $params->{borrowernumber}   # integer: borrowernumber
  $params->{amount}           # decimal: amount top charge
  $params->{due}              # date: when is the item due
  $params->{claimlevel}       # integer (1..5): what claim ist it: 1st, 2nd, 3rd, 4th or 5th reminder
  $params->{due_since_days}   # integer (1..x): since when is it due
  $params->{substitute}       # hash ref with key value pairs for description message generation using a letter template

=cut

sub AddClaimFee {
    my ($self,$params) = @_;

    my $issue_id       = $params->{issue_id};
    my $itemnum        = $params->{itemnumber};
    my $borrowernumber = $params->{borrowernumber};
    my $amount         = $params->{amount};
    my $due            = $params->{due};
    my $level          = $params->{claimlevel};
    my $due_since_days = $params->{due_since_days};
    my $branchcode     = $params->{branchcode};

    # $debug and warn "AddClaimFee({ itemnumber => $itemnum, borrowernumber => $borrowernumber, type => $type, due => $due, issue_id => $issue_id})";

    unless ( $issue_id ) {
        carp("No issue_id passed in!");
        return;
    }
    
    my $overdues = Koha::Account::Lines->search(
        {
            borrowernumber    => $borrowernumber,
            debit_type_code   => [ 'OVERDUE','CLAIM_LEVEL_1','CLAIM_LEVEL_2','CLAIM_LEVEL_3','CLAIM_LEVEL_4','CLAIM_LEVEL_5' ],
            amountoutstanding => { '<>' => 0 }
        }
    );
    
    my $accountline;
    my $total_amount = 0.00;
    # Cycle through the fines and
    # - find line that relates to the requested $itemnum
    # - accumulate fines for other items
    # so we can update $itemnum fine taking in account fine caps
    while (my $overdue = $overdues->next) {
        $total_amount += $overdue->amountoutstanding;
    }

    if (my $maxfine = C4::Context->preference('MaxFine')) {
        if ($total_amount + $amount > $maxfine) {
            my $new_amount = $maxfine - $total_amount;
            return if $new_amount <= 0.00;
            warn "Reducing fine for item $itemnum borrower $borrowernumber from $amount to $new_amount - MaxFine reached";
            $amount = $new_amount;
        }
    }

    if ( $amount ) { # Don't add new fines with an amount of 0
        
        my $desc = $self->GetClaimingFeeDescription($params);

        my $account = Koha::Account->new({ patron_id => $borrowernumber });
        my $accountline = $account->add_debit(
            {
                amount      => $amount,
                description => $desc,
                note        => undef,
                user_id     => undef,
                interface   => C4::Context->interface,
                library_id  => $branchcode,
                type        => 'CLAIM_LEVEL'.$level,
                item_id     => $itemnum,
                issue_id    => $issue_id,
            }
        );

        # logging action
        &logaction(
        "FINES",
            'CLAIM_LEVEL'.$level,
            $borrowernumber,
            "due=".$due."  amount=".$amount." itemnumber=".$itemnum
        ) if C4::Context->preference("FinesLog");
    }
}

=head2 GetClaimingFeeDescription

  $claimfees->GetClaimingFeeDescription($params);

Create the description for the claiming fee. Describes the reason for the fee in the user accout.
It's possible to use a letter template to generate the description as a localized string.
Simply create a letter with mdoule "fines" and code FINESMSG_ODUE_CLAIM. Optionally you can create
specific messages for each claim level using the code FINESMSG_ODUE_CLAIM1 to FINESMSG_ODUE_CLAIM5.
The letter text can contain branches, biblio, items, biblioitems and issues fields. Additionally 
the following keywords can be used:

=over 

=item <<today>>

Date of today.

=item <<overduedays>>

Days the item is overdue.

=item <<claimlevel>>

Claim level from 1 to 5.

=item <<claimfee>>

Charged amount.

If no letter template is defined, a simple description consisting of title and due date will be used.

=back

=cut

sub GetClaimingFeeDescription {
    my ($self,$params) = @_;
    
    my $branchcode = $params->{branchcode};
    
    # Let's check whether the library has configured a letter template 
    # to format a fancy fines description that we add with the claim fee
    my $letter_code = 'FINESMSG_ODUE_CLAIM'.$params->{'claimlevel'};
    my $template = Koha::Notice::Templates->find_effective_template(
            {
                module                 => 'fines',
                code                   => $letter_code,
                branchcode             => $branchcode,
                message_transport_type => 'email'
            }
    );
    my $letter_exists = ($template) ? 1 : 0;
    
    if ( $letter_exists == 0 ) {
        $letter_code = 'FINESMSG_ODUE_CLAIM';
        $template = Koha::Notice::Templates->find_effective_template(
				{
					module                 => 'fines',
					code                   => $letter_code,
					branchcode             => $branchcode,
					message_transport_type => 'email'
				}
		);
		$letter_exists = ($template) ? 1 : 0;
    }

    if ( $letter_exists ) {
        my $substitute = $params->{'substitute'} || {};
        $substitute->{today} ||= output_pref( { dt => dt_from_string, dateonly => 1} );
        $substitute->{overduedays} = $params->{due_since_days};
        $substitute->{claimlevel}  = $params->{claimlevel};
        
        my $active_currency = Koha::Acquisition::Currencies->get_active;

        my $currency_format;
        $currency_format = $active_currency->currency if defined($active_currency);
        
        $substitute->{'claimfee'} = currency_format($currency_format, $params->{amount}, FMT_SYMBOL);
        # if active currency isn't correct ISO code fallback to sprintf
        $substitute->{'claimfee'} = sprintf('%.2f', $params->{amount}) unless $substitute->{'claimfee'};

        my ($biblionumber,$itemnumber) = '';
        my @item_tables;
        if ( my $i = $params->{'items'} ) {
            my $item_format = '';
            foreach my $item (@$i) {
                my $fine = GetFine($item->{'itemnumber'}, $params->{'borrowernumber'}) + $params->{amount};
                
                $item->{'fine'} = currency_format($currency_format, $fine, FMT_SYMBOL);
                # if active currency isn't correct ISO code fallback to sprintf
                $item->{'fine'} = sprintf('%.2f', $fine) unless $item->{'fine'};
                
                push @item_tables, {
                    'biblio' => $item->{'biblionumber'},
                    'biblioitems' => $item->{'biblionumber'},
                    'items' => $item,
                    'issues' => $item->{'itemnumber'}
                };
                $biblionumber = $item->{'biblionumber'};
                $itemnumber = $item->{'itemnumber'};
                
            }
        }
        
        my %tables = ( 'borrowers' => $params->{'borrowernumber'} );
        if ( my $p = $params->{'branchcode'} ) {
            $tables{'branches'} = $p;
            $tables{'biblio'} = $biblionumber;
            $tables{'items'} = $itemnumber;
            $tables{'biblioitems'} = $biblionumber;
        }

        my $letter = C4::Letters::GetPreparedLetter (
            module => 'fines',
            letter_code => $letter_code,
            branchcode => $params->{'branchcode'},
            tables => \%tables,
            substitute => $substitute,
            repeat => { item => \@item_tables },
            message_transport_type => 'email'
        );
        return $letter->{'content'};
    }
    # no letter is defined, we use the default message
    else {
        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare(
            "SELECT title FROM biblio LEFT JOIN items ON biblio.biblionumber=items.biblionumber WHERE items.itemnumber=?"
        );
        $sth->execute($params->{itemnumber});
        my $title = $sth->fetchrow;
        $sth->finish();

        my $desc = "$title, " . $params->{due};
        
        return $desc;
    }
}

1;
