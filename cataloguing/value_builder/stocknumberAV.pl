#!/usr/bin/perl

# Converted to new plugin style (Bug 13437)

# Copyright 2012 BibLibre SARL
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

use C4::Auth;
use C4::Context;
use C4::Output;

=head1 DESCRIPTION

This plugin is based on authorised values INVENTORY.
It is used for stocknumber computation.

If the user send an empty string, we return a simple incremented stocknumber.
If a prefix is submited, we look for the highest stocknumber with this prefix, and return it incremented.
In this case, a stocknumber has this form : "PREFIX 0009678570".
 - PREFIX is an upercase word
 - a space separator
 - 10 digits, with leading 0s if needed

=cut

my $builder = sub {
    my ( $params ) = @_;
    my $res = qq{
    <script type='text/javascript'>
        function Click$params->{id}() {
                var code = document.getElementById('$params->{id}');
                \$.ajax({
                    url: '/cgi-bin/koha/cataloguing/plugin_launcher.pl',
                    type: 'POST',
                    data: {
                        'plugin_name': 'stocknumberAV.pl',
                        'code'    : code.value,
                    },
                    success: function(data){
                        var field = document.getElementById('$params->{id}');
                        field.value = data;
                        return 1;
                    }
                });
        }
    </script>
    };

    return $res;
};

my $launcher = sub {
    my ( $params ) = @_;
    my $input = $params->{cgi};
    my $code = $input->param('code');

    my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {   template_name   => "cataloguing/value_builder/ajax.tt",
            query           => $input,
            type            => "intranet",
            authnotrequired => 0,
            flagsrequired   => { editcatalogue => '*' },
            debug           => 1,
        }
    );

    my $dbh = C4::Context->dbh;

    # If a prefix is submited, we look for the highest stocknumber with this prefix, and return it incremented
    $code =~ s/ *$//g;
    if ( $code =~ m/^[A-Z]+$/ ) {
        my $sth = $dbh->prepare("SELECT lib FROM authorised_values WHERE category='INVENTORY' AND authorised_value=?");
        $sth->execute( $code);

        if ( my $valeur = $sth->fetchrow ) {
            $template->param( return => $code . ' ' . sprintf( '%010s', ( $valeur + 1 ) ), );
            my $sth2 = $dbh->prepare("UPDATE authorised_values SET lib=? WHERE category='INVENTORY' AND authorised_value=?");
            $sth2->execute($valeur+1,$code);
        } else {
                $template->param( return => "There is no defined value for $code");
        }
        # The user entered a custom value, we don't touch it, this could be handled in js
    } else {
        $template->param( return => $code, );
    }

    output_html_with_http_headers $input, $cookie, $template->output;
};

return { builder => $builder, launcher => $launcher };
