package C4::External::EKZ::BestellsystemWSDL;

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

use CGI::Carp;

use C4::External::EKZ::BudgetCheckElement;
use C4::External::EKZ::DublettenCheckElement;
use C4::External::EKZ::BestellInfoElement;


# special response element name required because the ekz web services are not perfecly SOAP conform
sub getResponseName {
    my ($requestName) = @_;
    my $responseName = "BestellsystemWSDLDummyResponseName";
    
    if ( defined $requestName ) {
        if ( $requestName eq "BudgetCheckElement" ) {
            $responseName = "BudgetCheckResultElement";
        } elsif ( $requestName eq "DublettenCheckElement" ) {
            $responseName = "DublettenCheckResultElement";
        } elsif ( $requestName eq "BestellInfoElement" ) {
            $responseName = "BestellInfoResultElement";
        }
    }
    return $responseName;
}

sub BudgetCheckElement {
    my $budgetCheckElement = C4::External::EKZ::BudgetCheckElement->new();
    return $budgetCheckElement->process(@_);
}

sub DublettenCheckElement {
    my $dublettenCheckElement = C4::External::EKZ::DublettenCheckElement->new();
    return $dublettenCheckElement->process(@_);
}

sub BestellInfoElement {
    my $bestellInfoElement = C4::External::EKZ::BestellInfoElement->new();
    return $bestellInfoElement->process(@_);
}

sub NotImplementedElement {
    return C4::External::EKZ::BudgetCheckElement::NotImplementedElement(@_);
}

1;
