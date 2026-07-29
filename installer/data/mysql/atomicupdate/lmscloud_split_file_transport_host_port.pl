use Modern::Perl;
use Koha::Installer::Output qw(say_info say_success);

return {
    bug_number  => "LMSCLOUD-split-file-transport-host-port",
    description =>
        "Split legacy 'host:port' values in file_transports.host into host + port (LMS sites stored host:port in vendor_edi_accounts.host before upstream migration in db_revs/250600022.pl)",
    up => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('file_transports') ) {
            say_info( $out, "file_transports table not present yet (Bug 39190 not applied), skipping" );
            return;
        }

        my $rows = $dbh->selectall_arrayref(
            q{SELECT file_transport_id, host, port FROM file_transports WHERE host LIKE '%:%'},
            { Slice => {} }
        );

        unless ( $rows && @$rows ) {
            say_info( $out, "No file_transports rows with 'host:port' format found, nothing to migrate" );
            return;
        }

        my $update_sth = $dbh->prepare(q{UPDATE file_transports SET host = ?, port = ? WHERE file_transport_id = ?});

        my $migrated = 0;
        for my $row (@$rows) {
            my $orig = $row->{host};
            if ( $orig =~ /^(.+):(\d+)$/ ) {
                my ( $new_host, $new_port ) = ( $1, $2 );
                $update_sth->execute( $new_host, $new_port, $row->{file_transport_id} );
                say_success(
                    $out,
                    sprintf(
                        "file_transport_id=%d: split '%s' -> host='%s', port=%d (was port=%s)",
                        $row->{file_transport_id}, $orig, $new_host, $new_port, $row->{port} // 'NULL'
                    )
                );
                $migrated++;
            } else {
                say_info(
                    $out,
                    sprintf(
                        "file_transport_id=%d: host '%s' contains ':' but does not match host:port pattern, leaving untouched",
                        $row->{file_transport_id}, $orig
                    )
                );
            }
        }

        say_success( $out, "Migrated $migrated file_transports rows from legacy host:port format" );
    },
};
