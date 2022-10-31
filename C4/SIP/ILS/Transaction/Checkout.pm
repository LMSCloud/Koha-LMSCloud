#
# An object to handle checkout status
#

package C4::SIP::ILS::Transaction::Checkout;

use warnings;
use strict;

use POSIX qw(strftime);
use C4::SIP::Sip qw(siplog);
use Data::Dumper;
use CGI qw ( -utf8 );

use C4::SIP::ILS::Transaction;

use C4::Context;
use C4::Circulation;
use C4::Members;
use C4::Reserves qw(ModReserveFill);
use C4::Debug;
use Koha::DateUtils;

use parent qw(C4::SIP::ILS::Transaction);

our $debug;


# Most fields are handled by the Transaction superclass
my %fields = (
          security_inhibit => 0,
          due              => undef,
          renew_ok         => 0,
    );

sub new {
    my $class = shift;;
    my $self = $class->SUPER::new();
    foreach my $element (keys %fields) {
        $self->{_permitted}->{$element} = $fields{$element};
    }
    @{$self}{keys %fields} = values %fields;
#    $self->{'due'} = time() + (60*60*24*14); # two weeks hence
    $debug and warn "new ILS::Transaction::Checkout : " . Dumper $self;
    return bless $self, $class;
}

sub do_checkout {
	my $self = shift;
    my $account = shift;
	siplog('LOG_DEBUG', "ILS::Transaction::Checkout performing checkout...");
    my $shelf          = $self->{item}->hold_attached;
	my $barcode        = $self->{item}->id;
    my $patron         = Koha::Patrons->find($self->{patron}->{borrowernumber});
    my $overridden_duedate; # usually passed as undef to AddIssue
    my $prevcheckout_block_checkout  = $account->{prevcheckout_block_checkout};
    $debug and warn "do_checkout borrower: . " . $patron->borrowernumber;
    my ($issuingimpossible, $needsconfirmation) = _can_we_issue($patron, $barcode, 0);

    my $noerror=1;  # If set to zero we block the issue
    my $chargeerror=0;
    if (keys %{$issuingimpossible}) {
        foreach (keys %{$issuingimpossible}) {
            # do something here so we pass these errors
            $self->screen_msg("Issue failed : $_");
            $noerror = 0;
            last;
        }
    } elsif (scalar keys %$needsconfirmation) {
        foreach my $confirmation (sort keys %{$needsconfirmation}) {
            if ($confirmation eq 'RENEW_ISSUE'){
                $self->screen_msg("Item already checked out to you: renewing item.");
            } elsif ($confirmation eq 'RESERVED' and !C4::Context->preference("AllowItemsOnHoldCheckoutSIP")) {
                $self->screen_msg("Item is reserved for another patron upon return.");
                $noerror = 0;
            } elsif ($confirmation eq 'RESERVED' and C4::Context->preference("AllowItemsOnHoldCheckoutSIP")) {
                next;
            } elsif ($confirmation eq 'RESERVE_WAITING'
                      or $confirmation eq 'TRANSFERRED'
                      or $confirmation eq 'PROCESSING') {
               $debug and warn "Item is on hold for another patron.";
               $self->screen_msg("Item is on hold for another patron.");
               $noerror = 0;
            } elsif ($confirmation eq 'ISSUED_TO_ANOTHER') {
                $self->screen_msg("Item already checked out to another patron.  Please return item for check-in.");
                $noerror = 0;
                last;
            } elsif ($confirmation eq 'DEBT') {
                $self->screen_msg('Outstanding Fines block issue');
                $noerror = 0;
                last;
            } elsif ($confirmation eq 'HIGHHOLDS') {
                $overridden_duedate = $needsconfirmation->{$confirmation}->{returndate};
                $self->screen_msg('Loan period reduced for high-demand item');
            } elsif ($confirmation eq 'RENTALCHARGE') {
                if ($self->{fee_ack} ne 'Y') {
                    $chargeerror = 1;
                }
            } elsif ($confirmation eq 'PREVISSUE') {
                $self->screen_msg("This item was previously checked out by you");
                $noerror = 0 if ($prevcheckout_block_checkout);
                last if ($prevcheckout_block_checkout);
            } elsif ( $confirmation eq 'ADDITIONAL_MATERIALS' ) {
                $self->screen_msg('Item must be checked out at a circulation desk');
                $noerror = 0;
                last;
            } else {
                # We've been returned a case other than those above
                $self->screen_msg("Item cannot be issued: $confirmation");
                $noerror = 0;
                siplog('LOG_DEBUG', "Blocking checkout Reason:$confirmation");
                last;
            }
        }
    }
    my $itemnumber = $self->{item}->{itemnumber};
    my ($fee, undef) = GetIssuingCharges($itemnumber, $patron->borrowernumber);
    if ( $fee > 0 ) {
        $self->{sip_fee_type} = '06';
        $self->{fee_amount} = sprintf '%.2f', $fee;
        if ($self->{fee_ack} eq 'N' && $noerror ) {
            $noerror = 0;
            # Display a confirmation about issuing charges only if there are no other errors blocking the checkout
            # E.g. a patrons confirms a charge and cannot borrow the book later due to an age restriction
            $self->screen_msg("Please confirm issuing charges!");
        }
    }
    # Just in case $chargerror was set as $needsconfirmation result and $noerror is still not set 
    # which actually should never happen because GetIssuingCharges should return a fee > 0
    if ( $noerror && $chargeerror ) {
        $noerror = 0;
        $self->screen_msg("Unconfirmed rental charges block checkout!");
    }

	unless ($noerror) {
		$debug and warn "cannot issue: " . Dumper($issuingimpossible) . "\n" . Dumper($needsconfirmation);
		$self->ok(0);
		return $self;
	}
	# can issue
    $debug and warn sprintf("do_checkout: calling AddIssue(%s, %s, %s, 0)\n", $patron->borrowernumber, $barcode, $overridden_duedate)
		. "w/ C4::Context->userenv: " . Dumper(C4::Context->userenv);
    my $issue = AddIssue( $patron->unblessed, $barcode, $overridden_duedate, 0 );
    $self->{due} = $self->duedatefromissue($issue, $itemnumber);

    $self->ok(1);
    return $self;
}

sub _can_we_issue {
    my ( $patron, $barcode, $pref ) = @_;

    my ( $issuingimpossible, $needsconfirmation, $alerts ) =
      CanBookBeIssued( $patron, $barcode, undef, 0, $pref );
    for my $href ( $issuingimpossible, $needsconfirmation ) {

        # some data is returned using lc keys we only
        foreach my $key ( keys %{$href} ) {
            if ( $key =~ m/[^A-Z_]/ ) {
                delete $href->{$key};
            }
        }
    }
    return ( $issuingimpossible, $needsconfirmation );
}

1;
__END__
