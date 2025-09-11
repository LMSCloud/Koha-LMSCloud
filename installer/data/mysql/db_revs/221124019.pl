use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => q{},
    description =>
        "Set all rows with lingering NULL for can_be_sold to 0 as per current schema's default for account_debit_types",
    up => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $stmt     = q{UPDATE account_debit_types SET can_be_sold = 0 WHERE can_be_sold IS NULL};
        my $affected = $dbh->do($stmt);

        if ( !defined $affected ) {
            say_failure(
                $out, sprintf q{Failed to update 'account_debit_types.can_be_sold': %s},
                $dbh->errstr // 'unknown error'
            );
            return;
        }

        if ( $affected eq '0E0' || $affected == 0 ) {
            say_info( $out, "No rows required updating ('account_debit_types.can_be_sold' already non-NULL)" );
            return;
        }

        say_success( $out, sprintf q{Set 'can_be_sold' to 0 for %d row(s) in 'account_debit_types'}, $affected );
    },
};
