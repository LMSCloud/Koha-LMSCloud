#!/usr/bin/perl

# Copyright 2024 LMSCloud GmbH
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

use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use Koha::AuthorisedValues;

=head1 DESCRIPTION

This plugin is based on authorised values from category NUMBER_GENERATOR_PREFIX.
It is used for a flexible number computation based on a prefix in the catalog.

If no valid prefix is submitted, it returns the inserted value (= keep the field unchanged).

If a prefix is submitted, we look for a fitting authorised value  of category NUMBER_GENERATOR_PREFIX.
If found, we increase the value in lib and format the number based on 
a specification in lib_opac. The specification can contain the following value
<COUNT NUMBER POSITIONS>|<SEPARATOR>.

In this case, a number was generated, it has the form (e.g. "<PREFIX><SEPARATOR><COUNT NUMBER POSITIONS>"):
The separator is empty by default 

=cut

my $builder = sub {
    my ( $params ) = @_;
    my $res = qq{
    <script>
        function Click$params->{id}() {
                var code = document.getElementById('$params->{id}');
                \$.ajax({
                    url: '/cgi-bin/koha/cataloguing/plugin_launcher.pl',
                    type: 'POST',
                    data: {
                        'plugin_name': 'cat_number_generator.pl',
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
            flagsrequired   => { editcatalogue => '*' },
            debug           => 1,
        }
    );

    # If a prefix is submited, we look for the lib value of the found authorised record with this prefix, and return it incremented lib value. 
    # The number of positions and the separator can specified in lib_opac using the syntax <COUNT NUMBER POSITIONS>|<SEPARATOR>
    $code =~ s/ *$//g;
    if ( $code ) {
        my $av = Koha::AuthorisedValues->find({
            'category' => 'NUMBER_GENERATOR_PREFIX',
            'authorised_value' => $code
        });
        if ( $av ) {
			my $posANDsep = $av->lib_opac;
			my $positions = 6;
			my $separator = '';
			
            $av->lib($av->lib + 1);
            $av->store;
            
            if ( $posANDsep ) {
				if ( $posANDsep =~ /^([0-9]+)(\|(.+))?$/ ) {
					$positions = $1 if ( $1 );
					$separator = $3 if ( $3 );
				}
			}
            
            $template->param( return => $code . $separator . sprintf("%0${positions}s", ( $av->lib ) ), );
        } else {
            $template->param( return => $code );
        }
        # The user entered a custom value, we don't touch it, this could be handled in js
    } else {
        $template->param( return => $code );
    }

    output_html_with_http_headers $input, $cookie, $template->output;
};

return { builder => $builder, launcher => $launcher };
