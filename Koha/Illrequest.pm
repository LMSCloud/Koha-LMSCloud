package Koha::Illrequest;

# Backwards-compatibility shim — upstream renamed to Koha::ILL::Request in 24.11
# Provides checkIfIllItem (LMS-only, called from 12+ sites).
# Delegates all other method calls to Koha::ILL::Request via AUTOLOAD.
# Does NOT use 'parent' to avoid C3 circular dependency
# (Koha::ILL::Request references Koha::Illrequest at line 2442).

use Modern::Perl;

use C4::Context;

=head1 NAME

Koha::Illrequest - Backwards-compatibility shim for Koha::ILL::Request

=head1 METHODS

=head2 checkIfIllItem

    my ( $itisanillitem, $illrequest ) = Koha::Illrequest->checkIfIllItem($item);

Check if item is an ILL item (indicated by $item->{itype} matching a value in the
IllItemtypes syspref). Returns a two-element list: a boolean and, when true, the
first matching Koha::ILL::Request found for the item's biblio.

=cut

sub checkIfIllItem {
    my ( $class, $itemUnblessed ) = @_;

    my $itisanillitem = 0;
    my $illrequesthit;

    if ( C4::Context->preference("IllModule") ) {
        my @illItemtypes = split( /\|/, C4::Context->preference("IllItemtypes") // '' );
        foreach my $illItemtype (@illItemtypes) {
            if ( $illItemtype eq $itemUnblessed->{'itype'} ) {
                $itisanillitem = 1;
                last;
            }
        }
        if ($itisanillitem) {
            eval {
                require Koha::ILL::Requests;
                my $illrequests    = Koha::ILL::Requests->new();
                my $illrequesthits = $illrequests->search( { biblio_id => $itemUnblessed->{'biblionumber'} } );
                $illrequesthit = $illrequesthits->next();
            };
        }
    }
    return ( $itisanillitem, $illrequesthit );
}

=head2 AUTOLOAD

Delegate all other method calls to Koha::ILL::Request.

=cut

sub can {
    my ( $self, $method ) = @_;
    my $native = $self->SUPER::can($method);
    return $native if $native;
    require Koha::ILL::Request;
    return Koha::ILL::Request->can($method);
}

our $AUTOLOAD;

sub AUTOLOAD {
    my ( $self, @args ) = @_;
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';

    require Koha::ILL::Request;

    if ( ref $self ) {
        return $self->{_delegate}->$method(@args);
    } else {
        return Koha::ILL::Request->$method(@args);
    }
}

=head2 new

Delegate constructor to Koha::ILL::Request, wrapping the result.

=cut

sub new {
    my ( $class, @args ) = @_;
    require Koha::ILL::Request;
    my $delegate = Koha::ILL::Request->new(@args);
    return bless { _delegate => $delegate }, $class;
}

1;
