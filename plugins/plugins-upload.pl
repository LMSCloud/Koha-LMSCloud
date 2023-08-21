#!/usr/bin/perl

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

use Archive::Extract;
use CGI qw ( -utf8 );
use Mojo::UserAgent;
use File::Temp;

use C4::Context;
use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use C4::Members;
use Koha::Logger;
use Koha::Plugins;

my $plugins_enabled = C4::Context->config("enable_plugins");

my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name => ($plugins_enabled) ? "plugins/plugins-upload.tt" : "plugins/plugins-disabled.tt",
        query         => $input,
        type          => "intranet",
        flagsrequired   => { plugins => 'manage' },
    }
);

my $uploadfilename = $input->param('uploadfile');
my $uploadfile     = $input->upload('uploadfile');
my $uploadlocation = $input->param('uploadlocation');
my $op             = $input->param('op') || q{};

my ( $tempfile, $tfh );

my %errors;

if ($plugins_enabled) {
    if ( ( $op eq 'Upload' ) && ( $uploadfile || $uploadlocation ) ) {
        my $plugins_dir = C4::Context->config("pluginsdir");
        $plugins_dir = ref($plugins_dir) eq 'ARRAY' ? $plugins_dir->[0] : $plugins_dir;

        my $dirname = File::Temp::tempdir( CLEANUP => 1 );

        my $filesuffix;
        $filesuffix = $1 if $uploadfilename =~ m/(\..+)$/i;
        ( $tfh, $tempfile ) = File::Temp::tempfile( SUFFIX => $filesuffix, UNLINK => 1 );

        $errors{'NOTKPZ'} = 1 if ( $uploadfilename !~ /\.kpz$/i );
        $errors{'NOWRITETEMP'}    = 1 unless ( -w $dirname );
        $errors{'NOWRITEPLUGINS'} = 1 unless ( -w $plugins_dir );

        if ( $uploadlocation ) {
            my $ua = Mojo::UserAgent->new(max_redirects => 5);
            my $tx = $ua->get($uploadlocation);
            $tx->result->content->asset->move_to($tempfile);
        } else {
            $errors{'EMPTYUPLOAD'}    = 1 unless ( length($uploadfile) > 0 );
        }

        if (%errors) {
            $template->param( ERRORS => [ \%errors ] );
        } else {
            if ( $uploadfile ) {
                while (<$uploadfile>) {
                    print $tfh $_;
                }
                close $tfh;
            }

            my $ae = Archive::Extract->new( archive => $tempfile, type => 'zip' );
            unless ( $ae->extract( to => $plugins_dir ) ) {
                warn "ERROR: " . $ae->error;
                $errors{'UZIPFAIL'} = $uploadfilename;
                $template->param( ERRORS => [ \%errors ] );
                output_html_with_http_headers $input, $cookie, $template->output;
                exit;
            }

            Koha::Plugins->new()->InstallPlugins();
        }
    } elsif ( ( $op eq 'Upload' ) && !$uploadfile && !$uploadlocation ) {
        warn "Problem uploading file or no file uploaded.";
    }

    if ( ($uploadfile || $uploadlocation) && !%errors && !$template->param('ERRORS') ) {
        print $input->redirect("/cgi-bin/koha/plugins/plugins-home.pl");
    } else {
        output_html_with_http_headers $input, $cookie, $template->output;
    }

} else {
    output_html_with_http_headers $input, $cookie, $template->output;
}
