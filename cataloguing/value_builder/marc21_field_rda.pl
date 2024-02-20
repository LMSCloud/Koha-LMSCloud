#!/usr/bin/perl

# Copyright 2021 LMSCloud GmbH
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

use C4::Auth qw( get_template_and_user );
use CGI qw ( -utf8 );
use C4::Context;

use Koha::AuthorisedValues;
use C4::Output qw( output_html_with_http_headers );

my $builder = sub {
    my ( $params ) = @_;
    my $function_name = $params->{id};
    my $res           = "
<script>

function Click$function_name(event) {
    currentvalue=document.getElementById(event.data.id).value;
    newin=window.open(\"../cataloguing/plugin_launcher.pl?plugin_name=marc21_field_rda.pl&index=\"+ event.data.id +\"&result=\"+currentvalue,\"tag_editor\",'width=500,height=300,toolbar=false,scrollbars=yes');
    return false;
}

</script>
";

    return $res;
};

my $launcher = sub {
    my ( $params ) = @_;
    my $input = $params->{cgi};
    my $index   = $input->param('index');
    my $result  = $input->param('result');

    my $dbh = C4::Context->dbh;

    my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {   template_name   => "cataloguing/value_builder/marc21_field_rda.tt",
            query           => $input,
            type            => "intranet",
            flagsrequired   => { editcatalogue => '*' },
            debug           => 1,
        }
    );
    
    my $field = '336';
    my $authvalues = [];
    my $subfield_a = $index;
    my $subfield_b = $subfield_a;
    my $subfield_2 = $subfield_a;
    
    if ( $index =~ s/subfield_[a-x0-9]/subfield_a/ ) {
        
        $subfield_b =~ s/subfield_[a-x0-9](_[0-9]+_).+$/subfield_b$1/;
        $subfield_2 =~ s/subfield_[a-x0-9](_[0-9]+_).+$/subfield_2$1/;
        
        my $subfield_2_value;
        
        if ( $index =~ /tag_([0-9]{3})/ ) {
            $field = $1;
            
            if ( $field eq '336' ) {
                $subfield_2_value = 'rdacontent';
            }
            elsif ( $field eq '337' ) {
                $subfield_2_value = 'rdamedia';
            }
            elsif ( $field eq '338' ) {
                $subfield_2_value = 'rdacarrier';
            }
        }
        
        my $categoryname = "MARC-FIELD-$field-SELECT";
        
        my $authorisedValueSearch = Koha::AuthorisedValues->search({ category => $categoryname },{ order_by => ['lib'] });
        
        if ( $authorisedValueSearch->count ) {
            while ( my $authval = $authorisedValueSearch->next ) {
                push @$authvalues, { authvalue => $authval->authorised_value, authname => $authval->lib, rdaname  => $subfield_2_value};
            }
        }  
    }
    

    $template->param(
        index            => $index,
        subfield_a       => $subfield_a,
        subfield_b       => $subfield_b,
        subfield_2       => $subfield_2,
        authvalues       => $authvalues,
        rdafield         => $field,
        currval          => $result
    );
    output_html_with_http_headers $input, $cookie, $template->output;
};

return { builder => $builder, launcher => $launcher };
