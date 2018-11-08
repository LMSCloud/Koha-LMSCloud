package C4::External::EKZ::EkzAuthentication;

# Copyright 2017 (C) LMSCLoud GmbH
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

use utf8;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(authenticate);
use Digest::MD5 qw(md5_base64);

use Koha::AuthUtils qw(hash_password);
use C4::Context;


my $debugIt = 1;

sub authenticate{
    my ($userid, $pw) = @_;
    my $authenticated = 0;
    my $dbh = C4::Context->dbh;

    my $patron = Koha::Patrons->search( { userid => $userid } )->next();
    if ( defined($patron) && &checkpw( $dbh, $patron->borrowernumber(), $pw ) ) {
        $authenticated = 1;
    }
print STDERR "EkzAuthentication::authenticate() returns authenticated:" . $authenticated . ":\n" if $debugIt;
    return $authenticated;
}

sub checkpw {
    my ( $dbh, $borrowernumber, $pw ) = @_;
    my $ret = 0;

    my $sth = $dbh->prepare("SELECT password FROM borrowers WHERE borrowernumber=?");
    $sth->execute($borrowernumber);

    if ( $sth->rows ) {
        my $hash;
        my ($stored_hash) = $sth->fetchrow;
        if ( substr($stored_hash,0,2) eq '$2') {
            $hash = hash_password($pw, $stored_hash);
        } else {
            $hash = md5_base64($pw);
        }
        if ( $hash eq $stored_hash ) {
            $ret = 1;
        }
    }
    return $ret;
}

sub ekzLocalServicesEnabled {
    my $ekzLocalServicesEnabled = C4::Context->preference('ekzLocalServicesEnabled');

print STDERR "EkzAuthentication::ekzLocalServicesEnabled() returns ekzLocalServicesEnabled:" . $ekzLocalServicesEnabled . ":\n" if $debugIt;
    return $ekzLocalServicesEnabled;
}

sub kohaInstanceName {
    my $kohaInstanceName = substr(C4::Context->config('database'),5);  # Regrettably the Koha instance name is not configured, so we take database name (e.g. 'koha_wallenheim') and cut away the leading part 'koha_'.

print STDERR "EkzAuthentication::kohaInstanceName() returns kohaInstanceName:" . $kohaInstanceName . ":\n" if $debugIt;
    return $kohaInstanceName;
}

1;
