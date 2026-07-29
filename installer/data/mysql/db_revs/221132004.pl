use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);


return {
    bug_number  => undef,
    description => "Add acquisition_import_viewer permission under tools",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(q{
            INSERT IGNORE INTO permissions (module_bit, code, description)
            VALUES (13, 'acquisition_import_viewer', 'Access to Acquisition Import Viewer')
        });

        say_success( $out, "Added permission: tools -> acquisition_import_viewer" );
    },
};