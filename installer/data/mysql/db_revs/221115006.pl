use Modern::Perl;

return {
    bug_number => "",
    description => "UPDATE default system preferences to LMSCloud Koha standard.",
    up => sub {
        my ($args) = @_;
        my ($dbh) = @$args{qw(dbh)};
        
        $dbh->do(q{UPDATE systempreferences set value = '0' WHERE variable = 'TranslateNotices'});
        $dbh->do(q{UPDATE systempreferences set value = '1' WHERE variable = 'showLastPatron'});
        $dbh->do(q{UPDATE systempreferences set value = '50' WHERE variable = 'numReturnedItemsToShow'});
        $dbh->do(q{UPDATE systempreferences set value = '1' WHERE variable = 'IntranetAddMastheadLibraryPulldown'});
        $dbh->do(q{UPDATE systempreferences set value = 'contains' WHERE variable = 'DefaultPatronSearchMethod'});
        $dbh->do(q{UPDATE systempreferences set value = '1' WHERE variable = 'OPACSuggestionAutoFill'});
        $dbh->do(q{UPDATE systempreferences set value = 'transfer' WHERE variable = 'ListOwnershipUponPatronDeletion'});
        $dbh->do(q{UPDATE systempreferences set value = 'codemirror' WHERE variable = 'AdditionalContentsEditor'});
        $dbh->do(q{UPDATE systempreferences set value = '' WHERE variable = 'OPACMandatoryHoldDates'});

    },
};
