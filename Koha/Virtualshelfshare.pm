package Koha::Virtualshelfshare;

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
use DateTime;
use DateTime::Duration;

use Koha::Database;
use Koha::DateUtils;
use Koha::Exceptions;

use base qw(Koha::Object);

use constant SHARE_INVITATION_EXPIRY_DAYS => 14; #two weeks to accept

=head1 NAME

Koha::Virtualshelfshare - Koha Virtualshelfshare Object class

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub accept {
    my ( $self, $invitekey, $borrowernumber ) = @_;
    if ( $self->has_expired ) {
        Koha::Exceptions::Virtualshelves::ShareHasExpired->throw;
    }
    if ( $self->invitekey ne $invitekey ) {
        Koha::Exceptions::Virtualshelves::InvalidInviteKey->throw;
    }

    # If this borrower already has a share, there is no need to accept twice
    # We solve this by 'pretending' to reaccept, but delete instead
    my $search = Koha::Virtualshelfshares->search({ shelfnumber => $self->shelfnumber, borrowernumber => $borrowernumber, invitekey => undef });
    if( $search->count ) {
        $self->delete;
        return $search->next;
    } else {
        $self->invitekey(undef);
        $self->sharedate(dt_from_string);
        $self->borrowernumber($borrowernumber);
        $self->store;
        return $self;
    }
}

sub has_expired {
    my ($self) = @_;
    my $dt_sharedate     = dt_from_string( $self->sharedate, 'sql' );
    my $today            = dt_from_string;
    my $expiration_delay = DateTime::Duration->new( days => SHARE_INVITATION_EXPIRY_DAYS );
    my $has_expired = DateTime->compare( $today, $dt_sharedate->add_duration($expiration_delay) );
    # Note: has_expired = 0 if the share expires today
    return $has_expired == 1 ? 1 : 0
}

sub _type {
    return 'Virtualshelfshare';
}

1;
