#!/usr/bin/perl

# Copyright 2011-2013 Biblibre SARL
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
use C4::Serials::Frequency qw( GetSubscriptionFrequency );
use C4::Auth qw( check_cookie_auth );
use JSON qw( to_json );

my $input=CGI->new;
my $frqid=$input->param("frequency_id");
my ($auth_status) = check_cookie_auth($input->cookie('CGISESSID'), { serials => '*' });
if ($auth_status ne "ok") {
    exit 0;
}
my $frequencyrecord=GetSubscriptionFrequency($frqid);
binmode STDOUT, ":encoding(UTF-8)";
print $input->header(-type => 'text/plain', -charset => 'UTF-8');
print to_json( $frequencyrecord );
