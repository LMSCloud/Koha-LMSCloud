use Modern::Perl;

return {
    bug_number => "LMSCLoud: Update description of debity type code NEW_CARD",
    description => "Update description of debity type code NEW_CARD",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        
        $dbh->do(qq{
            UPDATE account_debit_types SET description='Neuer Ausweis' WHERE code='NEW_CARD' AND ( description = '' OR description IS NULL )
        });
        
        say_success($out "LMSCloud update: description of debity type code NEW_CARD updated.");
    },
};
