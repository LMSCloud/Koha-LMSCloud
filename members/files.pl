#!/usr/bin/perl

# Copyright 2012 ByWater Solutions
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

use CGI qw ( -utf8 );

use C4::Auth;
use C4::Branch;
use C4::Output;
use C4::Members;
use C4::Members::Attributes qw(GetBorrowerAttributes);
use C4::Debug;

use Koha::DateUtils;
use Koha::Patron::Files;
use Koha::Patron::Images;

my $cgi = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "members/files.tt",
        query           => $cgi,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1 },
        debug           => 1,
    }
);
$template->param( 'borrower_files' => 1 );

my $borrowernumber = $cgi->param('borrowernumber');
my $bf = Koha::Patron::Files->new( borrowernumber => $borrowernumber );

my $op = $cgi->param('op') || '';

if ( $op eq 'download' ) {
    my $file_id = $cgi->param('file_id');
    my $file = $bf->GetFile( id => $file_id );

    print $cgi->header(
        -type       => $file->{'file_type'},
        -charset    => 'utf-8',
        -attachment => $file->{'file_name'}
    );
    print $file->{'file_content'};
}
else {
    my $data = GetMember( borrowernumber => $borrowernumber );
    $template->param(%$data);

    my %errors;

    if ( $op eq 'upload' ) {
        my $uploaded_file = $cgi->upload('uploadfile');

        if ($uploaded_file) {
            my $filename = $cgi->param('uploadfile');
            my $mimetype = $cgi->uploadInfo($filename)->{'Content-Type'};

            $errors{'empty_upload'} = 1 if ( -z $uploaded_file );

            if (%errors) {
                $template->param( errors => %errors );
            }
            else {
                my $file_content;
                while (<$uploaded_file>) {
                    $file_content .= $_;
                }

                $bf->AddFile(
                    name    => $filename,
                    type    => $mimetype,
                    content => $file_content,
                    description => scalar $cgi->param('description'),
                );
            }
        }
        else {
            $errors{'no_file'} = 1;
        }
    } elsif ( $op eq 'delete' ) {
        $bf->DelFile( id => scalar $cgi->param('file_id') );
    }

    $template->param(
        categoryname    => $data->{'description'},
        branchname      => GetBranchName($data->{'branchcode'}),
        RoutingSerials => C4::Context->preference('RoutingSerials'),
    );

    if (C4::Context->preference('ExtendedPatronAttributes')) {
        my $attributes = GetBorrowerAttributes($borrowernumber);
        $template->param(
            ExtendedPatronAttributes => 1,
            extendedattributes => $attributes
        );
    }

    my $patron_image = Koha::Patron::Images->find($data->{borrowernumber});
    $template->param( picture => 1 ) if $patron_image;

    $template->param( adultborrower => 1 ) if ( $data->{category_type} eq 'A' || $data->{category_type} eq 'I' );
    $template->param(
        files => Koha::Patron::Files->new( borrowernumber => $borrowernumber )
          ->GetFilesInfo(),

        errors => \%errors,
    );
    output_html_with_http_headers $cgi, $cookie, $template->output;
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut
