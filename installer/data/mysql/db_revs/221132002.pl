use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);
return {
    bug_number  => '',
    description => "Add system preferences 'HelimaAdditionalOfferName', 'HelimaCustomerID', 'HelimaLicensor', 'HelimaSearchActive', 'HelimaNumSearchResults', 'HeLiMaSearchCollections'",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};
        $dbh->do( "
            INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES
            ('HelimaAdditionalOfferName','Land Hessen',NULL,'Name of the Licensor/Provider of the HeLiMa service.','Free'),
            ('HelimaCustomerID','',NULL,'The customer ID when using the HeLiMa service.','Free'),
            ('HelimaLicensor','hessian',NULL,'Licensor/provider of the HeLiMa service.','Free'),
            ('HelimaNumSearchResults','20',NULL,'Maximum number of results per page displayed in the OPAC.','Integer'),
            ('HelimaSearchActive','0',NULL,'Activate the HeLiMa license manager search in OPAC.','YesNo'),
            ('HeLiMaSearchCollections','',NULL,'Limit the HeLiMa search result to the following list of collections. Separate HeLiMa collection names by |. This parameter is optional.','Free')
        " );
        say_success( $out, "Added new system preferences 'HelimaAdditionalOfferName', 'HelimaCustomerID', 'HelimaLicensor', 'HelimaSearchActive', 'HelimaNumSearchResults', 'HeLiMaSearchCollections'." );
    },
};
