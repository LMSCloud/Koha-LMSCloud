#!/usr/bin/perl


# Copyright 2000-2002 Katipo Communications
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

use Koha::Util::FrameworkPlugin qw(wrapper);
use C4::Auth;
use CGI qw ( -utf8 );
use C4::Context;

use C4::Search;
use C4::Output;

sub plugin_javascript {
    my ( $dbh, $record, $tagslib, $field_number, $tabloop ) = @_;
    my $res = "
<script type=\"text/javascript\">
function Clic$field_number() {
	defaultvalue=document.getElementById(\"$field_number\").value;
	window.open(\"../cataloguing/plugin_launcher.pl?plugin_name=unimarc_field_115b.pl&index=$field_number&result=\"+defaultvalue,\"unimarc_field_115b\",'width=1200,height=600,toolbar=false,scrollbars=yes');

}
</script>
";

    return ( $field_number, $res );
}


sub plugin {
    my ($input) = @_;
    my $index   = $input->param('index');
    my $result  = $input->param('result');

    my $dbh = C4::Context->dbh;
    my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {
            template_name =>
              "cataloguing/value_builder/unimarc_field_115b.tt",
            query           => $input,
            type            => "intranet",
            authnotrequired => 0,
            flagsrequired   => { editcatalogue => '*' },
            debug           => 1,
        }
    );
    my $f1  = substr( $result, 0,  1 ); $f1  = wrapper( $f1 ) if $f1;
    my $f2  = substr( $result, 1,  1 ); $f2  = wrapper( $f2 ) if $f2;
    my $f3  = substr( $result, 2,  1 ); $f3  = wrapper( $f3 ) if $f3;
    my $f4  = substr( $result, 3,  1 ); $f4  = wrapper( $f4 ) if $f4;
    my $f5  = substr( $result, 4,  1 ); $f5  = wrapper( $f5 ) if $f5;
    my $f6  = substr( $result, 5,  1 ); $f6  = wrapper( $f6 ) if $f6;
    my $f7  = substr( $result, 6,  1 ); $f7  = wrapper( $f7 ) if $f7;
    my $f8  = substr( $result, 7,  1 ); $f8  = wrapper( $f8 ) if $f8;
    my $f9  = substr( $result, 8,  1 ); $f9  = wrapper( $f9 ) if $f9;
    my $f10 = substr( $result, 9,  4 );
    my $f11 = substr( $result, 13, 2 );

    $template->param(
        index   => $index,
        "f1$f1" => 1,
        "f2$f2" => 1,
        "f3$f3" => 1,
        "f4$f4" => 1,
        "f5$f5" => 1,
        "f6$f6" => 1,
        "f7$f7" => 1,
        "f8$f8" => 1,
        "f9$f9" => 1,
        "f10"   => $f10,
        "f11"   => $f11
    );
    output_html_with_http_headers $input, $cookie, $template->output;
}
