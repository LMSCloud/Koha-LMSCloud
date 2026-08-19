use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "LMSCLOUD-acquisition-import-viewer-permission",
    description => "Add the view_acquisition_import_log permission under tools",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $added = $dbh->do(
            q{INSERT IGNORE INTO permissions (module_bit, code, description)
              VALUES (13, 'view_acquisition_import_log', 'Access to Acquisition Import Viewer')}
        );

        # DBI returns the truthy string "0E0" for zero affected rows, so compare numerically
        if ( $added > 0 ) {
            say_success( $out, "Added permission: tools -> view_acquisition_import_log" );
        } else {
            say_info( $out, "Permission tools -> view_acquisition_import_log already present, skipping" );
        }
    },
};
