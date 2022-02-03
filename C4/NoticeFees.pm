package C4::NoticeFees;

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

use Modern::Perl;
use Carp;

use Locale::Currency::Format;

use Koha::NoticeFeeRule;
use Koha::NoticeFeeRules;
use Koha::Account;
use Koha::DateUtils;
use C4::Log; # logaction


=head1 NAME

C4::NoticeFees - Koha module to charge notice fees 

=head1 SYNOPSIS

  my $noticeFees = C4::NoticeFees->new();
  my $noticeFeeRule = $noticeFees->getNoticeFeeRule($branchcode, $categorycode, $message_transport_type, $letter_code);
  if ( $noticeFeeRule ) {
     $fee = $noticeFeeRule->notice_fee;
     if ( $fee && $fee > 0.0 ) {
         $noticeFees->AddNoticeFee({
             borrowernumber => $borrowernumber,
             amount         => $fee,
             letter_date    => output_pref( { dt => dt_from_string, dateonly => 1 } ),
             claimlevel     => $claimlevel,
            
             # these are parameters that we need for fancy message printig
             branchcode     => $branchcode,
             substitute     => {
                                    bib             => $library->branchname, 
                                    'items.content' => $titles,
                                    'count'         => 1,
                                   },
             items          => \@items
         });
      }
  }

=head1 DESCRIPTION

The module is used to charge notice fees for sending notofications to borrowers. 
Notice fees are configured with the notice fee rules. A notice fee can be configured for 
branch libraries, patron types, message transport types, and letter codes.
A notice fee rule might combine the previously listed parameters.

If a library wants notice fees to be charged, it's necessary to add rules that apply to
a patron for specific notications which are created for instance with overdue reminders
or advanced notices. Only if a matching rule is found and if also the fee values is 
greater than 0.00, than the amiunt is charged.
The amount is typically charged during creation of the message.

The rules are applied from most specific to less specific, using the first found in this order:

=over 

=item *

same library, same patron type, same letter code, same message transport type

=item *

same library, same patron type, same letter code, all message transport types

=item *

same library, same patron type, all letter codes, same message transport type

=item *

same library, same patron type, all letter codes, all message transport types

=item *

same library, all patron types, same letter code, same message transport type

=item *

same library, all patron types, same letter code, all message transport types

=item *

same library, all patron types, all letter codes, same message transport type

=item *

same library, all patron types, all letter codes, all message transport types

=item *

default (all libraries), same patron type, same letter code, same message transport type

=item *

default (all libraries), same patron type, same letter code, all message transport types

=item *

default (all libraries), same patron type, all letter codes, same message transport type

=item *

default (all libraries), same patron type, all letter codes, all message transport types

=item *

default (all libraries), all patron types, same letter code, same message transport type

=item *

default (all libraries), all patron types, same letter code, all message transport types

=item *

default (all libraries), all patron types, all letter codes, same message transport type

=item *

default (all libraries), all patron types, all letter codes, all message transport types

=back

=head1 FUNCTIONS

=head2 new

  C4::NoticeFees->new()

Creates a new C4::NoticeFees object. During initialization, the currently defined notice fee 
rules of the instance are read. 

Returns a reference to the object.

=cut
sub new {
    my $class = shift;
    my $self  = bless { @_ }, $class;
    
    
    # read the notice fee rules for further processing
    my $noticeFeeRules = Koha::NoticeFeeRules->search({});
    
    my $rules = {};
    
    my $rules_count = 0;
    
    # assign a hash for fast checks whether a notice fee matches or not
    while ( my $rule = $noticeFeeRules->next() ) {
        $rules->{ $rule->branchcode() . "#\t#" . $rule->categorycode() . "#\t#" . $rule->letter_code() . "#\t#" . $rule->message_transport_type() } = $rule;
        $rules_count++;
    }
    
    # leave it with the object data
    $self->{'rules'} = $rules;
    $self->{'rules_count'} = $rules_count;

    return $self;
}



=head2 checkForNoticeFeeRules

  $zeroOrOne = $noticeFees->checkForNoticeFeeRules();

Returns whether there are notice fee rules defined. Returns 0 for no and 1 for yes.

=cut

sub checkForNoticeFeeRules {
    my $self = shift;
    
    return 1 if ( $self->{'rules_count'} > 0 );
    return 0;
}

=head2 getNoticeFeeRule

  $rule = $noticeFees->getNoticeFeeRule($branchcode, $categorycode, $message_transport_type, $letter_code) ;

Checks whether the is a matching notice fee rule for a combination of the four values:
branch code, patron category code, message transport type,  letter code.

=cut

sub getNoticeFeeRule {
    my ($self,$branchcode, $categorycode, $message_transport_type, $letter_code ) = @_;
    
    return undef if ( $self->{'rules_count'} == 0 );
    
    my $rules =  $self->{'rules'};

    foreach my $v (_getTestList($branchcode)) {
        foreach my $w (_getTestList($categorycode)) {
            foreach my $x (_getTestList($letter_code)) {
                foreach my $y (_getTestList($message_transport_type)) {
                    if (exists( $rules->{"$v#\t#$w#\t#$x#\t#$y"}) ) {
                        return $rules->{"$v#\t#$w#\t#$x#\t#$y"};
                    }
                }
            }
        }
    }
    
    return undef;
}

sub _getTestList {
    my $val = shift;
    my @list = ('*');
    unshift(@list, $val) if ($val && $val ne '*');
    return @list;
}

=head2 AddNoticeFee

  $noticeFees->AddNoticeFee($params) ;

Charges a notice fee to a borrower. The fee is added to the account of the borrower.
The function takes a hash reference as parameter. The hash ref is required to provide
the following data:

  $params->{branchcode}       # string: set the code of the branch
  $params->{borrowernumber}   # integer: borrowernumber
  $params->{amount}           # decimal: amount top charge
  $params->{letter_date}      # date: when is the notitification created
  $params->{letter_code}      # optional parameter letter code 
  $params->{claimlevel}       # integer: set the claimlevel if the notice is a reminder
  $params->{items}            # hashref: deliver item information
  $params->{substitute}       # hash ref with key value pairs for description message generation using a letter template

=cut

sub AddNoticeFee {
    my ($self,$params) = @_;


    my $borrowernumber = $params->{borrowernumber};
    my $amount         = $params->{amount};
    my $letter_date    = $params->{letter_date};
    my $branchcode     = $params->{branchcode};

    unless ( $borrowernumber ) {
        carp("No borrower number passed in!");
        return;
    }


    if ( $amount ) { # Don't add new fines with an amount of 0.00

        my $description = $self->GetNoticeFeeDescription($params);

        my $account = Koha::Account->new({ patron_id => $borrowernumber });
        my $accountline = $account->add_debit(
            {
                amount      => $amount,
                description => $description,
                note        => undef,
                user_id     => undef,
                interface   => C4::Context->interface,
                type        => 'NOTIFICATION',
                item_id     => undef,
                issue_id    => undef,
                library_id  => $branchcode
            }
        );

        # logging action
        &logaction(
        "FINES",
            'NOTIFICATION',
            $borrowernumber,
            "letter_date=".$letter_date." description=".$description." amount=".$amount
        ) if C4::Context->preference("FinesLog");
    }
    else {
        warn "Charging notice fee for borrower $borrowernumber with $amount is not supported";
    }
}

=head2 GetNoticeFeeDescription

  $claimfees->GetNoticeFeeDescription($params);

Create the description for the notice fee. Describes the reason for the fee in the user accout.
It's possible to use a letter template to generate the description as a localized string.
Simply create a letter with mdoule fine and code FINESMSG_NOTF. For overdue reminder notice fees
the specific code FINESMSG_NOTF_CLAIM can be used. Optionally you can also create specific messages 
for each claim level using the code FINESMSG_ODUE_CLAIM1 to FINESMSG_ODUE_CLAIM5.
The most specific letter found letter template will be used.
The letter text can contain branches fields. With the <item></item> tag you can add information for
each item of the notice for which the fee was created. Within the item tag you can use biblio, items, 
biblioitems and issues fields. Addintionally the followoingkeywords can be used:

=over 

=item <<today>>

Date of today.

=item <<claimlevel>>

Claim level from 1 to 5. Only available with for overdue reminder notices.

=item <<noticefee>>

Charged amount.

If no letter template is defined, a simple description consisting of the letter date will be used.

=back

=cut

sub GetNoticeFeeDescription {
    my ($self,$params) = @_;
    
    my $branchcode = $params->{branchcode};
    
    # Let's check whether the library has configured a letter template 
    # to format a fancy fines description that we add with the claim fee
    my $letter_code = 'FINESMSG_NOTF';
    my $letter_exists = 0;
    
    # if it is a overdue claim we support to format messages depending on the calim lebvel
    if ( $params->{'claimlevel'} ) {
        $letter_exists = C4::Letters::getletter( 'fines', $letter_code . '_CLAIM'.$params->{'claimlevel'}, $branchcode, 'email' ) ? 1 : 0;
        $letter_code = $letter_code . '_CLAIM'.$params->{'claimlevel'} if ($letter_exists);
        if (! $letter_exists ) {
            $letter_exists = C4::Letters::getletter( 'fines', $letter_code . '_CLAIM', $branchcode, 'email' ) ? 1 : 0;
            $letter_code = $letter_code . '_CLAIM' if ($letter_exists);
        }
    }
    elsif ( $params->{'letter_code'} ) {
        $letter_exists = C4::Letters::getletter( 'fines', $letter_code . '_' . $params->{'letter_code'}, $branchcode, 'email' ) ? 1 : 0;
        $letter_code = $letter_code . '_' . $params->{'letter_code'} if ($letter_exists);
    }
    if (! $letter_exists ) {
        $letter_exists = C4::Letters::getletter( 'fines', $letter_code, $branchcode, 'email' ) ? 1 : 0;
    }

    if ( $letter_exists ) {
        my $substitute = $params->{'substitute'} || {};
        $substitute->{today} ||= output_pref( { dt => dt_from_string, dateonly => 1} );
        $substitute->{claimlevel}  = $params->{claimlevel} if ( $params->{'claimlevel'} );
        
        my $active_currency = Koha::Acquisition::Currencies->get_active;

        my $currency_format;
        $currency_format = $active_currency->currency if defined($active_currency);
        
        $substitute->{'noticefee'} = currency_format($currency_format, $params->{amount}, FMT_SYMBOL);
        # if active currency isn't correct ISO code fallback to sprintf
        $substitute->{'noticefee'} = sprintf('%.2f', $params->{amount}) unless $substitute->{'noticefee'};


        
        my %tables = ();
        
        if ( $params->{'tables'} ) {
            %tables = %{$params->{'tables'}};
        }
        else {
            %tables = ( 'borrowers' => $params->{'borrowernumber'} );
            if ( my $p = $params->{'branchcode'} ) {
                $tables{'branches'} = $p;
            }
        }
        
        my $itemcount=0;
        my @item_tables;
        if ( my $i = $params->{'items'} ) {
            foreach my $item (@$i) {
                push @item_tables, {
                    'biblio' => $item->{'biblionumber'},
                    'biblioitems' => $item->{'biblionumber'},
                    'items' => $item,
                    'issues' => $item->{'itemnumber'},
                };
                $itemcount++;
            }
        }
        $substitute->{'itemcount'} = $itemcount;

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
        my $desc = $params->{letter_date};
        
        return $desc;
    }
}

1;
