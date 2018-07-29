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
my ($dbh,$record,$tagslib,$field_number,$tabloop) = @_;
my $function_name= $field_number;
my $res="
<script>
function Clic$function_name(i) {
	defaultvalue=document.getElementById(\"$field_number\").value;
	newin=window.open(\"../cataloguing/plugin_launcher.pl?plugin_name=unimarc_field_126a.pl&index=$field_number&result=\"+defaultvalue,\"unimarc_field_126a\",'width=1000,height=575,toolbar=false,scrollbars=yes');

}
</script>
";

return ($function_name,$res);
}


sub plugin {
my ($input) = @_;
	my $index= $input->param('index');
	my $result= $input->param('result');


	my $dbh = C4::Context->dbh;

my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "cataloguing/value_builder/unimarc_field_126a.tt",
			     query => $input,
			     type => "intranet",
			     authnotrequired => 0,
			     flagsrequired => {editcatalogue => '*'},
			     debug => 1,
			     });
	my $f1 = substr($result,0,1);
	my $f2 = substr($result,1,1);
	my $f3 = substr($result,2,1);
	my $f4 = substr($result,3,1);
	my $f5 = substr($result,4,1);
	my $f6 = substr($result,5,1);
	my $f7 = substr($result,6,1);
	my $f8 = substr($result,7,1); $f8 = wrapper( $f8 ) if $f8;
	my $f9 = substr($result,8,1); $f9 = wrapper( $f9 ) if $f9;
	my $f10 = substr($result,9,1); $f10 = wrapper( $f10 ) if $f10;
	my $f11 = substr($result,10,1); $f11 = wrapper( $f11 ) if $f11;
	my $f12 = substr($result,11,1); $f12 = wrapper( $f12 ) if $f12;
	my $f13 = substr($result,12,1); $f13 = wrapper( $f13 ) if $f13;
	my $f14 = substr($result,13,1);
	my $f15 = substr($result,14,1);
	$template->param(index => $index,
			 "f1$f1" => 1,
			 "f2$f2" => 1,
			 "f3$f3" => 1,
			 "f4$f4" => 1,
			 "f5$f5" => 1,
			 "f6$f6" => 1,
			 "f7$f7" => 1,
			 "f8$f8" => 1,
			 "f9$f9" => 1,
			 "f10$f10" => 1,
			 "f11$f11" => 1,
			 "f12$f12" => 1,
			 "f13$f13" => 1,
			 "f14$f14" => 1,
			 "f15$f15" => 1
);
        output_html_with_http_headers $input, $cookie, $template->output;
}
