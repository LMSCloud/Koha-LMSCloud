use Modern::Perl;

return {
    bug_number => "",
    description => "Update subscriptionhistory: set biblionumber to subscription.biblionumber where different from subscription.",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        
        my $res = $dbh->do(q{UPDATE subscriptionhistory 
                             JOIN subscription ON subscription.subscriptionid=subscriptionhistory.subscriptionid
                             SET subscriptionhistory.biblionumber = subscription.biblionumber
                             WHERE subscription.biblionumber <> subscriptionhistory.biblionumber
                            });
        $res += 0;
        say $out "Updated the biblionumber of $res subscriptionhistory rows.";
    },
};
