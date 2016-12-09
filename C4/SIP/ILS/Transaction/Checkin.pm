#
# An object to handle checkin status
#

package C4::SIP::ILS::Transaction::Checkin;

use warnings;
use strict;

# use POSIX qw(strftime);

use C4::SIP::ILS::Transaction;

use C4::Circulation;
use C4::Reserves qw( ModReserveAffect );
use C4::Items qw( ModItemTransfer );
use C4::Debug;
use Sys::Syslog qw(syslog);

use parent qw(C4::SIP::ILS::Transaction);

my %fields = (
    magnetic => 0,
    sort_bin => undef,
    collection_code  => undef,
    # 3M extensions:
    call_number      => undef,
    destination_loc  => undef,
    alert_type       => undef,  # 00,01,02,03,04 or 99
    hold_patron_id   => undef,
    hold_patron_name => "",
    hold             => undef,
);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();                # start with an ILS::Transaction object

    foreach (keys %fields) {
        $self->{_permitted}->{$_} = $fields{$_};    # overlaying _permitted
    }

    @{$self}{keys %fields} = values %fields;        # copying defaults into object
    return bless $self, $class;
}

sub do_checkin {
    my $self = shift;
    my $branch = shift;
    my $return_date = shift;
    my $checked_in_ok = shift;
    if (!$branch) {
        $branch = 'SIP2';
    }
    my $barcode = $self->{item}->id;

    $return_date =   substr( $return_date, 0, 4 )
                   . '-'
                   . substr( $return_date, 4, 2 )
                   . '-'
                   . substr( $return_date, 6, 2 )
                   . q{ }
                   . substr( $return_date, 12, 2 )
                   . ':'
                   . substr( $return_date, 14, 2 )
                   . ':'
                   . substr( $return_date, 16, 2 );

    $debug and warn "do_checkin() calling AddReturn($barcode, $branch)";
    my ($return, $messages, $iteminformation, $borrower) = AddReturn($barcode, $branch, undef, undef, $return_date);
    $self->alert(!$return);
    # ignoring messages: IsPermanent, WasLost, WasTransfered

    # biblionumber, biblioitemnumber, itemnumber
    # borrowernumber, reservedate, branchcode
    # cancellationdate, found, reservenotes, priority, timestamp

    # We ignore an error if the item was not checked in and if the SIP account 
    # parameter 'checked_in_ok' is set. That way, the device does not show an error 
    # if a such a medium is going to be returned.
    if ( $messages->{NotIssued} ) {
        if ($checked_in_ok) {
            $return = 1;
        }
        else {
            $self->screen_msg("Item not checked out") unless $checked_in_ok;
        }
        syslog("LOG_DEBUG", "C4::SIP::ILS::Transaction::Checkin:do_checkin - item not checked out");
    }
    if ($messages->{BadBarcode}) {
        $self->alert_type('99');
        syslog("LOG_DEBUG", "C4::SIP::ILS::Transaction::Checkin:do_checkin - bad barcode");
    }
    if ($messages->{withdrawn}) {
        $self->alert_type('99');
        syslog("LOG_DEBUG", "C4::SIP::ILS::Transaction::Checkin:do_checkin - item withdrawn");
    }
    if ($messages->{Wrongbranch}) {
        # wrong branch is an error since the library disabled it 
        # using configuration parameter 'AllowReturnToBranch' 
        $self->destination_loc($messages->{Wrongbranch}->{Rightbranch});
        $self->alert_type('04');                       
        $self->screen_msg("Return at wrong branch");
        $return = 0;
        syslog("LOG_DEBUG", "C4::SIP::ILS::Transaction::Checkin:do_checkin - return at wrong branch");  
    }
    if ($messages->{WrongTransfer}) {
        $self->destination_loc($messages->{WrongTransfer});
        $self->alert_type('04');            # send to other branch
        syslog("LOG_DEBUG", "C4::SIP::ILS::Transaction::Checkin:do_checkin - wrong transfer");
    }
    if ($messages->{NeedsTransfer}) {
        $self->destination_loc($iteminformation->{homebranch});
        $self->alert_type('04');            # send to other branch
        syslog("LOG_DEBUG", "C4::SIP::ILS::Transaction::Checkin:do_checkin - needs transfer");
    }
    if ($messages->{WasTransfered}) { # set into transit so tell unit
        $self->destination_loc($iteminformation->{homebranch});
        $self->alert_type('04');            # send to other branch
        syslog("LOG_DEBUG", "C4::SIP::ILS::Transaction::Checkin:do_checkin - was transfered");
    }
    if ($messages->{ResFound}) {
        syslog("LOG_DEBUG", "C4::SIP::ILS::Transaction::Checkin:do_checkin - reservation found");
        $self->hold($messages->{ResFound});
        if ($branch eq $messages->{ResFound}->{branchcode}) {
            $self->alert_type('01');
            ModReserveAffect( $messages->{ResFound}->{itemnumber},
                $messages->{ResFound}->{borrowernumber}, 0);

        } else {
            $self->alert_type('02');
            ModReserveAffect( $messages->{ResFound}->{itemnumber},
                $messages->{ResFound}->{borrowernumber}, 1);
            ModItemTransfer( $messages->{ResFound}->{itemnumber},
                $branch,
                $messages->{ResFound}->{branchcode}
            );

        }
        $self->{item}->hold_patron_id( $messages->{ResFound}->{borrowernumber} );
        $self->{item}->destination_loc( $messages->{ResFound}->{branchcode} );
    }

    $self->alert(1) if defined $self->alert_type;  # alert_type could be "00", hypothetically
    $self->ok($return);
}

sub resensitize {
	my $self = shift;
	unless ($self->{item}) {
		warn "resensitize(): no item found in object to resensitize";
		return;
	}
	return !$self->{item}->magnetic_media;
}

sub patron_id {
	my $self = shift;
	unless ($self->{patron}) {
		warn "patron_id(): no patron found in object";
		return;
	}
	return $self->{patron}->id;
}

1;
