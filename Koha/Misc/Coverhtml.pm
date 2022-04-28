package Koha::Misc::Coverhtml;

# This file is part of Koha.
#
# Copyright 2022 LMSCloud GmbH [Paul Derscheid]
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
use utf8;

use C4::Context;
use C4::External::BakerTaylor qw( image_url );

=head1 NAME

Koha::Misc::Coverhtml - module that checks system preferences for set
cover image providers and generates html accordingly; like the external
src block in opac-detail.tt

=head1 SYNOPSIS

use Koha::Misc::Coverhtml;

=head1 FUNCTIONS

=over

=item coverhtml()

=cut

sub coverhtml {
    my @items = @_;

    my $preferences = {
        'OPACLocalCoverImages'  => C4::Context->preference('OPACLocalCoverImages'),
        'OPACAmazonCoverImages' => C4::Context->preference('OPACAmazonCoverImages'),
        'SyndeticsEnabled'      => C4::Context->preference('SyndeticsEnabled'),
        'SyndeticsCoverImages'  => C4::Context->preference('SyndeticsCoverImages'),
        'SyndeticsClientCode'   => C4::Context->preference('SyndeticsClientCode'),
        'GoogleJackets'         => C4::Context->preference('GoogleJackets'),
        'BakerTaylorEnabled'    => C4::Context->preference('BakerTaylorEnabled'),
        'OpacCoce'              => C4::Context->preference('OpacCoce'),
        'CoceProviders'         => C4::Context->preference('CoceProviders'),
        'OPACCustomCoverImages' => C4::Context->preference('OPACCustomCoverImages'),
        'CustomCoverImagesUrl'  => C4::Context->preference('CustomCoverImagesUrl'),
    };

    my $index = 0;

    for my $item (@items) {

        my $image_title;
        my $coverhtml;
        my $item_coverurl = $item->{'coverurl'};

        if (!$item_coverurl && ( ( $preferences->{'OPACLocalCoverImages'} && $item->{'local_image_count'} > 0 ) || $preferences->{'OPACAmazonCoverImages'} || ( $preferences->{'SyndeticsEnabled'} && $preferences->{'SyndeticsCoverImages'} ) || $preferences->{'GoogleJackets'} || $preferences->{'BakerTaylorEnabled'} || ( $preferences->{'OpacCoce'} && $preferences->{'CoceProviders'} ) || ( $preferences->{'OPACCustomCoverImages'} && $preferences->{'CustomCoverImagesURL'} ) )) {
            if ($item->{'title'}) {
                $image_title = $item->{'title'};
            } else {
                $image_title = $item->{'biblionumber'};
            }

            if ($preferences->{'OPACLocalCoverImages'} && $item->{'local_image_count'} > 0) {
                $coverhtml = qq{<div title="$image_title" class="$item->{'biblionumber'} thumbnail-shelfbrowser" id="local-thumbnail-shelf-$item->{'biblionumber'}"></div>};
            }

            if ($preferences->{'OPACAmazonCoverImages'}) {
                if ($item->{'browser_normalized_isbn'}) {
                    $coverhtml = qq{<img src="https://images-na.ssl-images-amazon.com/images/P/$item->{'browser_normalized_isbn'}.01._AA75_PU_PU-5_.jpg" alt="" />};
                } else {
                    $coverhtml = q{<span class="no-image">No cover image available</span>};
                }
            }

            if ($preferences->{'SyndeticsEnabled'}) {
                if ($preferences->{'SyndeticsCoverImages'}) {
                    if ( $item->{'browser_normalized_isbn'} || $item->{'browser_normalized_upc'} || $item->{'browser_normalized_oclc'} ) {
                        $coverhtml = qq{<img src="https://secure.syndetics.com/index.aspx?isbn=$item->{'browser_normalized_isbn'}/SC.GIF&amp;client=$preferences->{'SyndeticsClientCode'}};
                        if ($item->{'browser_normalized_upc'}) {
                            $coverhtml .= qq{&amp;upc=$item->{'browser_normalized_upc'}};
                        }
                        if ($item->{'browser_normalized_oclc'}) {
                            $coverhtml .= qq{&amp;oclc=$item->{'browser_normalized_oclc'}};
                        }
                        $coverhtml .= q{&amp;type=xw10" alt="" />};
                    }
                }
            }

            if ($preferences->{'GoogleJackets'}) {
                if ($item->{'browser_normalized_isbn'}) {
                    $coverhtml = qq{<div title="$image_title" class="$item->{'browser_normalized_isbn'}" id="gbs-thumbnail-preview$index"></div>}; # loop count has to be implemented
                } else {
                    $coverhtml = q{<span class="no-image">No cover image available</span>};
                }
            }

            if ($preferences->{'OpacCoce'} && $preferences->{'CoceProviders'}) {
                my $coce_id = ( $item->{'browser_normalized_ean'} || $item->{'browser_normalized_isbn'} );
                $coverhtml = qq{<div title="$image_title" class="$coce_id" id="coce-thumbnail-preview-$coce_id"></div>}
            }

            if ($preferences->{'BakerTaylorEnabled'}) {
                my $baker_taylor_id = ( $item->{'browser_normalized_upc'} || $item->{'browser_normalized_isbn'} );
                my $baker_taylor_image_url = image_url();
                my $baker_taylor_src = $baker_taylor_id . $baker_taylor_image_url;
                if ($baker_taylor_id) {
                    $coverhtml = qq{<img alt="See Baker &amp; Taylor" src="$baker_taylor_src" />};
                } else {
                    $coverhtml = q{<span class="no-image">No cover image available</span>};
                }
            }

            if ($preferences->{'OPACCustomCoverImages'} && $preferences->{'CustomCoverImagesUrl'}) {
                my $custom_cover_image_url = $preferences->{'CustomCoverImagesUrl'};
                if ($custom_cover_image_url) {
                    $coverhtml = qq{<span class="custom_cover_image"><img alt="Cover image" src="$custom_cover_image_url" /></span>};
                }
            }
        }

        # Add the property coverhtml to our objects and push onto results array.
        $item->{'coverhtml'} = $coverhtml;

        # This index is needed for the loop count used in GoogleJackets markup.
        $index += 1; 
    }

    return \@items;
}

1;