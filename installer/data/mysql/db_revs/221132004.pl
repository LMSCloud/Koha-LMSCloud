use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);


return {
    bug_number  => undef,
    description => "Add view_acquisition_import_log permission under tools",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(q{
            INSERT IGNORE INTO permissions (module_bit, code, description)
            VALUES (13, 'view_acquisition_import_log', 'Access to Acquisition Import Viewer')
        });

        say_success( $out, "Added permission: tools -> view_acquisition_import_log" );
    },
};