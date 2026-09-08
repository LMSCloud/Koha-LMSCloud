use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "41131",
    description => "Delete transfer limits that are from a branch to the same branch",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Do you stuffs here
        $dbh->do(
            q{
            DELETE FROM branch_transfer_limits WHERE toBranch = fromBranch;
        }
        );
        say $out "Removed nonsensical transfer limits that prevent a branch transferring to itself";
    },
};
