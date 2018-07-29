package C4::External::BakerTaylor;

# Copyright (C) 2008 LibLime
# <jmf at liblime dot com>
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

use XML::Simple;
use LWP::Simple;
use HTTP::Request::Common;

use C4::Context;
use C4::Debug;

use Modern::Perl;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);

BEGIN {
	require Exporter;
	@ISA = qw(Exporter);
    $VERSION = 3.07.00.049;
	@EXPORT_OK = qw(&availability &content_cafe &image_url &link_url &http_jacket_link);
	%EXPORT_TAGS = (all=>\@EXPORT_OK);
}

# These variables are plack safe: they are initialized each time
my ( $user, $pass, $agent, $image_url, $link_url );

sub _initialize {
	$user     = (@_ ? shift : C4::Context->preference('BakerTaylorUsername')    ) || ''; # LL17984
	$pass     = (@_ ? shift : C4::Context->preference('BakerTaylorPassword')    ) || ''; # CC82349
	$link_url = (@_ ? shift : C4::Context->preference('BakerTaylorBookstoreURL'));
        $image_url = "https://contentcafe2.btol.com/ContentCafe/Jacket.aspx?UserID=$user&Password=$pass&Options=Y&Return=T&Type=S&Value=";
	$agent = "Koha/$VERSION [en] (Linux)";
			#"Mozilla/4.76 [en] (Win98; U)",	#  if for some reason you want to go stealth, you might prefer this
}

sub image_url {
    _initialize();
	($user and $pass) or return;
	my $isbn = (@_ ? shift : '');
	$isbn =~ s/(p|-)//g;	# sanitize
	return $image_url . $isbn;
}

sub link_url {
    _initialize();
	my $isbn = (@_ ? shift : '');
	$isbn =~ s/(p|-)//g;	# sanitize
	$link_url or return;
	return $link_url . $isbn;
}

sub content_cafe_url {
    _initialize();
	($user and $pass) or return;
	my $isbn = (@_ ? shift : '');
	$isbn =~ s/(p|-)//g;	# sanitize
    return "https://contentcafe2.btol.com/ContentCafeClient/ContentCafe.aspx?UserID=$user&Password=$pass&Options=Y&ItemKey=$isbn";
}

sub http_jacket_link {
    _initialize();
	my $isbn = shift or return;
	$isbn =~ s/(p|-)//g;	# sanitize
	my $image = availability($isbn);
	my $alt = "Buy this book";
	$image and $image = qq(<img class="btjacket" alt="$alt" src="$image" />);
	my $link = &link_url($isbn);
	unless ($link) {return $image || '';}
	return sprintf qq(<a class="btlink" href="%s">%s</a>),$link,($image||$alt);
}

sub availability {
    _initialize();
	my $isbn = shift or return;
	($user and $pass) or return;
	$isbn =~ s/(p|-)//g;	# sanitize
    my $url = "https://contentcafe2.btol.com/ContentCafe/InventoryAvailability.asmx/CheckInventory?UserID=$user&Password=$pass&Value=$isbn";
	$debug and warn __PACKAGE__ . " request:\n$url\n";
	my $content = get($url);
	$debug and print STDERR $content, "\n";
	warn "could not retrieve $url" unless $content;
	my $xmlsimple = XML::Simple->new();
	my $result = $xmlsimple->XMLin($content);
	if ($result->{Error}) {
		warn "Error returned to " . __PACKAGE__ . " : " . $result->{Error};
	}
	my $avail = $result->{Availability};
	return ($avail and $avail !~ /^false$/i) ? &image_url($isbn) : 0;
}

1;

__END__

=head1 NAME

C4::External::BakerTaylor

=head1 DESCRIPTION

Functions for retrieving content from Baker and Taylor, inventory availability and "Content Cafe".

The settings for this module are controlled by System Preferences:

These can be overridden for testing purposes using the initialize function.

=head1 FUNCTIONS

=head2 availability($isbn);

$isbn is a isbn string

=head1 NOTES

A request with failed authentication might see this back from Baker + Taylor: 

 <?xml version="1.0" encoding="utf-8"?>
 <InventoryAvailability xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" DateTime="2008-03-07T22:01:25.6520429-05:00" xmlns="http://ContentCafe2.btol.com">
   <Key Type="Undefined">string</Key>
   <Availability>false</Availability>
   <Error>Invalid UserID</Error>
 </InventoryAvailability>

Such response will trigger a warning for each request (potentially many).  Point being, do not leave this module configured with incorrect username and password in production.

=head1 SEE ALSO

LWP::UserAgent

=head1 AUTHOR

Joe Atzberger
atz AT liblime DOT com

=cut
