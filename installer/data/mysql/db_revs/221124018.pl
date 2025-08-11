use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number => "LMSCLoud: Update description of debity type code NEW_CARD",
    description => "Update description of debity type code NEW_CARD",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        
        $dbh->do(q{
            UPDATE account_debit_types SET description='Neuer Ausweis' WHERE code='NEW_CARD' AND ( description = '' OR description IS NULL )
        });
        
        say_success($out, "LMSCloud update: description of debity type code NEW_CARD updated.");
    },
};
