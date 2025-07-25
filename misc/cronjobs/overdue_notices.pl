#!/usr/bin/perl

# Copyright 2008 Liblime
# Copyright 2010 BibLibre
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Getopt::Long qw( GetOptions );
use Pod::Usage qw( pod2usage );
use Text::CSV_XS;
use DateTime;
use DateTime::Duration;

use Koha::Script -cron;
use C4::Context;
use C4::Letters;
use C4::Overdues qw( GetOverdueMessageTransportTypes parse_overdues_letter);
use C4::ClaimingFees;
use C4::NoticeFees;
use C4::Log qw( cronlogaction );
use Koha::Patron::Debarments qw(AddUniqueDebarment);
use Koha::DateUtils qw( dt_from_string output_pref );
use Koha::Calendar;
use Koha::Libraries;
use Koha::Acquisition::Currencies;
use Koha::OverdueIssue;
use Koha::Patrons;

=head1 NAME

overdue_notices.pl - prepare messages to be sent to patrons for overdue items

=head1 SYNOPSIS

overdue_notices.pl
  [ -n ][ --library <branchcode> ][ --library <branchcode> ... ]
  [ --max <number of days> ][ --csv [<filename>] ][ --itemscontent <field list> ]
  [ --email <email_type> ... ]

 Options:
   --help                          Brief help message.
   --man                           Full documentation.
   --verbose | -v                  Verbose mode. Can be repeated for increased output
   --nomail | -n                   No email will be sent.
   --max          <days>           Maximum days overdue to deal with.
   --library      <branchcode>     Only deal with overdues from this library.
                                   (repeatable : several libraries can be given)
   --csv          <filename>       Populate CSV file.
   --html         <directory>      Output html to a file in the given directory.
   --text         <directory>      Output plain text to a file in the given directory.
   --itemscontent <list of fields> Item information in templates.
   --borcat       <categorycode>   Category code that must be included.
   --borcatout    <categorycode>   Category code that must be excluded.
   --triggered | -t                Only include triggered overdues.
   --test                          Run in test mode. No changes will be made on the DB.
   --list-all                      List all overdues.
   --date         <yyyy-mm-dd>     Emulate overdues run for this date.
   --email        <email_type>     Type of email that will be used.
                                   Can be 'email', 'emailpro' or 'B_email'. Repeatable.
   --frombranch                    Organize and send overdue notices by home library (item-homebranch) or checkout library (item-issuebranch).
                                   This option is only used, if the OverdueNoticeFrom system preference is set to 'command-line option'.
                                   Defaults to item-issuebranch.

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<-v> | B<--verbose>

Verbose. Without this flag set, only fatal errors are reported.
A single 'v' will report info on branches, letter codes, and patrons.
A second 'v' will report The SQL code used to search for triggered patrons.

=item B<-n> | B<--nomail>

Do not send any email. Overdue notices that would have been sent to
the patrons or to the admin are printed to standard out. CSV data (if
the --csv flag is set) is written to standard out or to any csv
filename given.

=item B<--nocharge>

Do not charge notice fees or claiming fess even if claiming fee rules
or notice fee rules would require to charge fees.

=item B<--max>

Items older than max days are assumed to be handled somewhere else,
probably the F<longoverdues.pl> script. They are therefore ignored by
this program. No notices are sent for them, and they are not added to
any CSV files. Defaults to 90 to match F<longoverdues.pl>.

=item B<--library>

select overdues for one specific library. Use the value in the
branches.branchcode table. This option can be repeated in order 
to select overdues for a group of libraries.

=item B<--csv>

Produces CSV data. if -n (no mail) flag is set, then this CSV data is
sent to standard out or to a filename if provided. Otherwise, only
overdues that could not be emailed are sent in CSV format to the admin.

=item B<--html>

Produces html data. If patron does not have an email address or
-n (no mail) flag is set, an HTML file is generated in the specified
directory. This can be downloaded or further processed by library staff.
The file will be called notices-YYYY-MM-DD.html and placed in the directory
specified.

=item B<--text>

Produces plain text data. If patron does not have an email address or
-n (no mail) flag is set, a text file is generated in the specified
directory. This can be downloaded or further processed by library staff.
The file will be called notices-YYYY-MM-DD.txt and placed in the directory
specified.

=item B<--itemscontent>

comma separated list of fields that get substituted into templates in
places of the E<lt>E<lt>items.contentE<gt>E<gt> placeholder. This
defaults to due date,title,barcode,author

Other possible values come from fields in the biblios, items and
issues tables.

=item B<--borcat>

Repeatable field, that permits to select only some patron categories.

=item B<--borcatout>

Repeatable field, that permits to exclude some patron categories.

=item B<-t> | B<--triggered>

This option causes a notice to be generated if and only if 
an item is overdue by the number of days defined in a notice trigger.

By default, a notice is sent each time the script runs, which is suitable for 
less frequent run cron script, but requires syncing notice triggers with 
the  cron schedule to ensure proper behavior.
Add the --triggered option for daily cron, at the risk of no notice 
being generated if the cron fails to run on time.

=item B<--test>

This option makes the script run in test mode.

In test mode, the script won't make any changes on the DB. This is useful
for debugging configuration.

=item B<--list-all>

Default items.content lists only those items that fall in the 
range of the currently processing notice.
Choose --list-all to include all overdue items in the list (limited by B<--max> setting).

=item B<--date>

use it in order to send overdues on a specific date and not Now. Format: YYYY-MM-DD.

=item B<--email>

Allows to specify which type of email will be used. Can be email, emailpro or B_email. Repeatable.

=item B<--frombranch>

Organize overdue notices either by checkout library (item-issuebranch) or item home library (item-homebranch).
This option is only used, if the OverdueNoticeFrom system preference is set to use 'command-line option'.
Defaults to checkout library (item-issuebranch).

=back

=head1 DESCRIPTION

This script is designed to alert patrons and administrators of overdue
items.

=head2 Configuration

This script pays attention to the overdue notice configuration
performed in the "Overdue notice/status triggers" section of the
"Tools" area of the staff interface to Koha. There, you can choose
which letter templates are sent out after a configurable number of
days to patrons of each library. More information about the use of this
section of Koha is available in the Koha manual.

The templates used to craft the emails are defined in the "Tools:
Notices" section of the staff interface to Koha.

In addition the claim fee rules and the notice fee rules are considered
creating overdue reminders. A claiming fee will be charged if a claiming fee
rules matches for the item. Notice fess are applied to created letters
if a notice fee rules matches. Please verify that the claim fee rules and
the notice fee rules do meet your requirements.

Please be very carefully with claim fees if you do not use the -t / --triggered
option. Calling the script daily with -t prevents that a user is charged multiple
times for an item at the same claim level. If you want to charge claim fees and you
do not run the script daily with -t option, you need to run the script in a frequency
that is equal to the configured delay of the overdue alerts.

The parater --nocharge can be used to prevent that notice fees or claiming
fees are charged independently of the currently defined rule configuration.

=head2 Outgoing emails

Typically, messages are prepared for each patron with overdue
items. Messages for whom there is no email address on file are
collected and sent as attachments in a single email to each library
administrator, or if that is not set, then to the email address in the
C<KohaAdminEmailAddress> system preference.

These emails are staged in the outgoing message queue, as are messages
produced by other features of Koha. This message queue must be
processed regularly by the
F<misc/cronjobs/process_message_queue.pl> program.

In the event that the C<-n> flag is passed to this program, no emails
are sent. Instead, messages are sent on standard output from this
program. They may be redirected to a file if desired.

=head2 Templates

Templates can contain variables enclosed in double angle brackets like
E<lt>E<lt>thisE<gt>E<gt>. Those variables will be replaced with values
specific to the overdue items or relevant patron. Available variables
are:

=over

=item E<lt>E<lt>bibE<gt>E<gt>

the name of the library

=item E<lt>E<lt>items.contentE<gt>E<gt>

one line for each item, each line containing a tab separated list of
title, author, barcode, issuedate

=item E<lt>E<lt>borrowers.*E<gt>E<gt>

any field from the borrowers table

=item E<lt>E<lt>branches.*E<gt>E<gt>

any field from the branches table

=back

=head2 CSV output

The C<-csv> command line option lets you specify a file to which
overdues data should be output in CSV format.

With the C<-n> flag set, data about all overdues is written to the
file. Without that flag, only information about overdues that were
unable to be sent directly to the patrons will be written. In other
words, this CSV file replaces the data that is typically sent to the
administrator email address.

=head1 USAGE EXAMPLES

C<overdue_notices.pl> - In this most basic usage, with no command line
arguments, all libraries are processed individually, and notices are
prepared for all patrons with overdue items for whom we have email
addresses. Messages for those patrons for whom we have no email
address are sent in a single attachment to the library administrator's
email address, or to the address in the KohaAdminEmailAddress system
preference.

C<overdue_notices.pl -n --csv /tmp/overdues.csv> - sends no email and
populates F</tmp/overdues.csv> with information about all overdue
items.

C<overdue_notices.pl --library MAIN max 14> - prepare notices of
overdues in the last 2 weeks for the MAIN library.

=head1 SEE ALSO

The F<misc/cronjobs/advance_notices.pl> program allows you to send
messages to patrons in advance of their items becoming due, or to
alert them of items that have just become due.

=cut

# These variables are set by command line options.
# They are initially set to default values.
my $dbh = C4::Context->dbh();

my $help    = 0;
my $man     = 0;
my $verbose = 0;
my $nomail  = 0;
my $nocharge = 0;
my $MAX     = 90;
my $test_mode = 0;
my $frombranch = 'item-issuebranch';
my @branchcodes; # Branch(es) passed as parameter
my @emails_to_use;    # Emails to use for messaging
my @emails;           # Emails given in command-line parameters
my $csvfilename;
my $htmlfilename;
my $text_filename;
my $triggered = 0;
my $listall = 0;
my $itemscontent = join( ',', qw(date_due title barcode author itemnumber) );
my @myborcat;
my @myborcatout;
my $checkPreviousClaimLevel = 0;
my ( $date_input, $today );
my %debarredPatrons = ();

my $command_line_options = join(" ",@ARGV);

GetOptions(
    'help|?'         => \$help,
    'man'            => \$man,
    'v|verbose+'     => \$verbose,
    'n|nomail'       => \$nomail,
    'nocharge+'      => \$nocharge,
    'max=s'          => \$MAX,
    'library=s'      => \@branchcodes,
    'csv:s'          => \$csvfilename,    # this optional argument gets '' if not supplied.
    'html:s'         => \$htmlfilename,    # this optional argument gets '' if not supplied.
    'text:s'         => \$text_filename,    # this optional argument gets '' if not supplied.
    'itemscontent=s' => \$itemscontent,
    'list-all'       => \$listall,
    't|triggered'    => \$triggered,
    'test'           => \$test_mode,
    'date=s'         => \$date_input,
    'borcat=s'       => \@myborcat,
    'borcatout=s'    => \@myborcatout,
    'email=s'        => \@emails,
    'frombranch=s'   => \$frombranch,
) or pod2usage(2);
pod2usage(1) if $help;
pod2usage( -verbose => 2 ) if $man;
cronlogaction({ info => $command_line_options });

if ( defined $csvfilename && $csvfilename =~ /^-/ ) {
    warn qq(using "$csvfilename" as filename, that seems odd);
}

die "--frombranch takes item-homebranch or item-issuebranch only"
    unless ( $frombranch eq 'item-issuebranch'
        || $frombranch eq 'item-homebranch' );
$frombranch = C4::Context->preference('OverdueNoticeFrom') ne 'cron' ? C4::Context->preference('OverdueNoticeFrom') : $frombranch;
my $owning_library = ( $frombranch eq 'item-homebranch' ) ? 1 : 0;

$checkPreviousClaimLevel = 1 
    if C4::Context->preference('OverdueNoticePeriodCalculationMethod') eq 'byPreviousClaimLevel';
my @overduebranches    = C4::Overdues::GetBranchcodesWithOverdueRules();    # Branches with overdue rules
my @branches;                                    # Branches passed as parameter with overdue rules
my $branchcount = scalar(@overduebranches);

my $overduebranch_word = scalar @overduebranches > 1 ? 'branches' : 'branch';
my $branchcodes_word = scalar @branchcodes > 1 ? 'branches' : 'branch';

my $PrintNoticesMaxLines = C4::Context->preference('PrintNoticesMaxLines');

if ($branchcount) {
    $verbose and warn "Found $branchcount $overduebranch_word with first message enabled: " . join( ', ', map { "'$_'" } @overduebranches ), "\n";
} else {
    die 'No branches with active overduerules';
}

if (@branchcodes) {
    $verbose and warn "$branchcodes_word @branchcodes passed on parameter\n";
    
    # Getting libraries which have overdue rules
    my %seen = map { $_ => 1 } @branchcodes;
    @branches = grep { $seen{$_} } @overduebranches;
    
    
    if (@branches) {

        my $branch_word = scalar @branches > 1 ? 'branches' : 'branch';
    $verbose and warn "$branch_word @branches have overdue rules\n";

    } else {
    
        $verbose and warn "No active overduerules for $branchcodes_word  '@branchcodes'\n";
        ( scalar grep { '' eq $_ } @branches )
          or die "No active overduerules for DEFAULT either!";
        $verbose and warn "Falling back on default rules for @branchcodes\n";
        @branches = ('');
    }
}
my $date_to_run;
my $date;
if ( $date_input ){
    eval {
        $date_to_run = dt_from_string( $date_input, 'iso' );
    };
    die "$date_input is not a valid date, aborting! Use a date in format YYYY-MM-DD."
        if $@ or not $date_to_run;

    # It's certainly useless to escape $date_input
    # dt_from_string should not return something if $date_input is not correctly set.
    $date = $dbh->quote( $date_input );
}
else {
    $date="NOW()";
    $date_to_run = dt_from_string();
}

# these are the fields that will be substituted into <<item.content>>
my @item_content_fields = split( /,/, $itemscontent );

binmode( STDOUT, ':encoding(UTF-8)' );


our $csv;       # the Text::CSV_XS object
our $csv_fh;    # the filehandle to the CSV file.
if ( defined $csvfilename ) {
    my $sep_char = C4::Context->csv_delimiter;
    $csv = Text::CSV_XS->new( { binary => 1, sep_char => $sep_char, formula => "empty" } );
    if ( $csvfilename eq '' ) {
        $csv_fh = *STDOUT;
    } else {
        open $csv_fh, ">", $csvfilename or die "unable to open $csvfilename: $!";
    }
    if ( $csv->combine(qw(name surname address1 address2 zipcode city country email phone cardnumber itemcount itemsinfo branchname letternumber)) ) {
        print $csv_fh $csv->string, "\n";
    } else {
        $verbose and warn 'combine failed on argument: ' . $csv->error_input;
    }
}

@branches = @overduebranches unless @branches;

$verbose and warn "Using $branchcount $overduebranch_word with first message enabled: " . join( ', ', map { "'$_'" } @overduebranches ), "\n";

our $fh;
if ( defined $htmlfilename ) {
  if ( $htmlfilename eq '' ) {
    $fh = *STDOUT;
  } else {
    my $today = dt_from_string();
    open $fh, ">:encoding(UTF-8)",File::Spec->catdir ($htmlfilename,"notices-".$today->ymd().".html");
  }
  
  print $fh _get_html_start();
}
elsif ( defined $text_filename ) {
  if ( $text_filename eq '' ) {
    $fh = *STDOUT;
  } else {
    my $today = dt_from_string();
    open $fh, ">:encoding(UTF-8)",File::Spec->catdir ($text_filename,"notices-".$today->ymd().".txt");
  }
}

# Initialize the object to charge claiming fees if necessary.
# The new function reads the configuration of claiming fee rules.
# We use the object later to check whether an overdue item needs to be
# charged.
my $claimFees = C4::ClaimingFees->new();

# Initialize the objects to charge notice fees if necessary.
# The new function reads the configuration of notice fee rules.
# We use the object later to check whether a notice fee needs to be
# charged for sending an ovderdue letter.
my $noticeFees = C4::NoticeFees->new();

# The following processing loops through all branches.
# For each branch queries are prepared to select issues of a borrower and matching overduerules.
# For each matching overduerule it checks then that there is a delay and letter setup.
# If the matching rule has a complete setup, it can checked whether the there are issues that
# match the overdue rule.
# All matching issues are ordered by borrowernumber so that a borrower gets only one letter per
# matching overduerule.
foreach my $branchcode (@branches) {
    my $library             = Koha::Libraries->find($branchcode);
    next if (! $library);
    my $usebranch           = $branchcode;
    $usebranch = $library->mobilebranch if ( $library->mobilebranch );
    
    my $calendar;
    if ( C4::Context->preference('OverdueNoticeCalendar') || C4::Context->preference('OverdueNoticeSkipWhenClosed') ) {
        $calendar = Koha::Calendar->new( branchcode => $branchcode );
        if ( $calendar->is_holiday($date_to_run) ) {
            next;
        }
    }

    my $admin_email_address = $library->from_email_address;
    my $branch_email_address = C4::Context->preference('AddressForFailedOverdueNotices')
      || $library->inbound_email_address;
    my @output_chunks;    # may be sent to mail or stdout or csv file.

    $verbose and print "======================================\n";
    $verbose and warn sprintf "branchcode : '%s' using %s\n", $branchcode, $branch_email_address;

    my $mobileselect = '';
    if ( C4::Context->preference('BookMobileSupportEnabled') && !C4::Context->preference('BookMobileStationOverdueRulesActive')) {
        $mobileselect = 'OR b.mobilebranch = ?';
    }
    
    my $familyCardMemberOverdueReceiverSelect = '';
    if ( C4::Context->preference('FamilyCardMemberOverdueReceiver') eq 'owner' ) {
       $familyCardMemberOverdueReceiverSelect = ' OR issues.borrowernumber IN ( SELECT DISTINCT b.guarantee_id FROM borrower_relationships b, borrowers o, categories c ' .
                                                ' WHERE o.borrowernumber = ? AND o.borrowernumber = b.guarantor_id AND c.categorycode = o.categorycode AND c.family_card = 1)';
    }
    
    my $sql2 = <<"END_SQL";
SELECT biblio.*, items.*, issues.*, biblioitems.itemtype, itemtypes.description AS itemtypename, branchname, IFNULL(claim_level,0) as claim_level, IFNULL(DATE(claim_time),'0000-00-00') as claim_date, issues.branchcode as issuebranch
  FROM items LEFT JOIN itemtypes ON items.itype = itemtypes.itemtype, biblio, biblioitems, branches b, issues
  LEFT JOIN ( SELECT issue_id, MAX(claim_level) AS claim_level, MAX(claim_time) as claim_time FROM overdue_issues GROUP BY issue_id) oi ON (issues.issue_id=oi.issue_id)
  WHERE items.itemnumber=issues.itemnumber
    AND biblio.biblionumber   = items.biblionumber
    AND biblio.biblionumber   = biblioitems.biblionumber
    AND ( issues.borrowernumber = ? $familyCardMemberOverdueReceiverSelect )
    AND items.itemlost = 0
    AND TO_DAYS($date)-TO_DAYS(issues.date_due) >= 0
    AND ( b.branchcode = ? $mobileselect )
END_SQL

    if($owning_library) {
      $sql2 .= ' AND b.branchcode = items.homebranch ';
    } else {
      $sql2 .= ' AND b.branchcode = issues.branchcode ';
    }
    my $sth2 = $dbh->prepare($sql2);

    my $query = "SELECT * FROM overduerules WHERE delay1 IS NOT NULL AND branchcode = ? ";
    $query .= " AND categorycode IN (".join( ',' , ('?') x @myborcat ).") " if (@myborcat);
    $query .= " AND categorycode NOT IN (".join( ',' , ('?') x @myborcatout ).") " if (@myborcatout);
    
    my $rqoverduerules =  $dbh->prepare($query);
    $rqoverduerules->execute($branchcode, @myborcat, @myborcatout);
    
    # If it is a mobile branch station check wether there are rules for the mobile branch
    if ( $library->mobilebranch && ($rqoverduerules->rows == 0 || !C4::Context->preference('BookMobileStationOverdueRulesActive')) ){
        $query = "SELECT * FROM overduerules WHERE delay1 IS NOT NULL AND branchcode = ? ";
        $query .= " AND categorycode IN (".join( ',' , ('?') x @myborcat ).") " if (@myborcat);
        $query .= " AND categorycode NOT IN (".join( ',' , ('?') x @myborcatout ).") " if (@myborcatout);
        
        $rqoverduerules = $dbh->prepare($query);
        $rqoverduerules->execute($library->mobilebranch, @myborcat, @myborcatout);
    }
    
    # We get default rules is there is no rule for this branch
    if($rqoverduerules->rows == 0){
        $query = "SELECT * FROM overduerules WHERE delay1 IS NOT NULL AND branchcode = '' ";
        $query .= " AND categorycode IN (".join( ',' , ('?') x @myborcat ).") " if (@myborcat);
        $query .= " AND categorycode NOT IN (".join( ',' , ('?') x @myborcatout ).") " if (@myborcatout);
        
        $rqoverduerules = $dbh->prepare($query);
        $rqoverduerules->execute(@myborcat, @myborcatout);
    }

    # my $outfile = 'overdues_' . ( $mybranch || $branchcode || 'default' );
    while ( my $overdue_rules = $rqoverduerules->fetchrow_hashref ) {
      PERIOD: foreach my $i ( 1 .. 5 ) {

            $verbose and warn "branch '$branchcode', categorycode = $overdue_rules->{categorycode} pass $i\n";

            my $mindays = $overdue_rules->{"delay$i"};    # the notice will be sent after mindays days (grace period)
            my $maxdays = (
                  $overdue_rules->{ "delay" . ( $i + 1 ) }
                ? $overdue_rules->{ "delay" . ( $i + 1 ) } - 1
                : ($MAX)
            );                                            # issues being more than maxdays late are managed somewhere else. (borrower probably suspended)

            next unless defined $mindays;

            if ( !$overdue_rules->{"letter$i"} ) {
                $verbose and warn sprintf "No letter code found for pass %s\n", $i;
                next PERIOD;
            }
            $verbose and warn sprintf "Using letter code '%s' for pass %s\n", $overdue_rules->{"letter$i"}, $i;

            # $letter->{'content'} is the text of the mail that is sent.
            # this text contains fields that are replaced by their value. Those fields must be written between brackets
            # The following fields are available :
            # itemcount is interpreted here as the number of items in the overdue range defined by the current notice or all overdues < max if(-list-all).
            # <date> <itemcount> <firstname> <lastname> <address1> <address2> <address3> <city> <postcode> <country>

            my $exludeFamilyCardMembers = '';
            if ( C4::Context->preference('FamilyCardMemberOverdueReceiver') eq 'owner' ) {
                $exludeFamilyCardMembers = 'AND NOT EXISTS (SELECT 1 FROM borrower_relationships r, borrowers b, categories c WHERE borrowers.borrowernumber = r.guarantee_id and b.borrowernumber = r.guarantor_id AND c.categorycode = b.categorycode AND c.family_card = 1)';
            }
            my $branchsel = 'branches.branchcode = issues.branchcode';
            if ( $owning_library ) {
                $branchsel = 'branches.branchcode = items.homebranch';
            }
            my $borrower_sql = <<"END_SQL";
SELECT DISTINCT borrowers.borrowernumber, firstname, surname, address, address2, city, zipcode, country, email, emailpro, B_email, smsalertnumber, phone, 
                cardnumber, date_due, IFNULL(claim_level,0) as claim_level, IFNULL(DATE(claim_time),'0000-00-00') as claim_date, issues.branchcode
FROM   branches, borrowers, categories, items, issues
LEFT JOIN ( SELECT issue_id, MAX(claim_level) AS claim_level, MAX(claim_time) as claim_time FROM overdue_issues GROUP BY issue_id) oi ON (issues.issue_id=oi.issue_id)
WHERE  issues.borrowernumber = borrowers.borrowernumber $exludeFamilyCardMembers
AND    borrowers.categorycode=categories.categorycode
AND    issues.itemnumber = items.itemnumber
AND    items.itemlost = 0
AND    categories.overduenoticerequired=1
AND    $branchsel
AND    TO_DAYS($date)-TO_DAYS(issues.date_due) >= 0
END_SQL
            my @borrower_parameters;
            if ($branchcode) {
                if ( C4::Context->preference('BookMobileSupportEnabled') && !C4::Context->preference('BookMobileStationOverdueRulesActive')) {
                    $borrower_sql .= 'AND ( branches.branchcode = ? OR branches.mobilebranch = ? )';
                    push @borrower_parameters, $branchcode, $branchcode;
                } else {
                    $borrower_sql .= 'AND branches.branchcode = ?';
                    push @borrower_parameters, $branchcode;
                }
            }
            if ( $overdue_rules->{categorycode} ) {
                $borrower_sql .= ' AND borrowers.categorycode=? ';
                push @borrower_parameters, $overdue_rules->{categorycode};
            }
            if ( $exludeFamilyCardMembers ) {
                $borrower_sql .= <<"END_SQL";
UNION
SELECT DISTINCT owner.borrowernumber, owner.firstname, owner.surname, owner.address, owner.address2, owner.city, owner.zipcode, owner.country, owner.email, owner.emailpro, owner.B_email, owner.smsalertnumber, owner.phone, 
                owner.cardnumber, date_due, IFNULL(claim_level,0) as claim_level, IFNULL(DATE(claim_time),'0000-00-00') as claim_date, issues.branchcode
FROM   branches, borrowers owner, borrowers familiy_member, borrower_relationships rel, categories, items, issues
LEFT JOIN ( SELECT issue_id, MAX(claim_level) AS claim_level, MAX(claim_time) as claim_time FROM overdue_issues GROUP BY issue_id) oi ON (issues.issue_id=oi.issue_id)
WHERE  categories.family_card = 1
AND    issues.borrowernumber = familiy_member.borrowernumber
AND    familiy_member.borrowernumber = rel.guarantee_id
AND    owner.borrowernumber = rel.guarantor_id
AND    NOT EXISTS ( SELECT 1 FROM borrowers b, categories c WHERE b.borrowernumber = familiy_member.borrowernumber AND c.categorycode = b.categorycode AND c.family_card = 1)
AND    owner.categorycode=categories.categorycode
AND    issues.itemnumber = items.itemnumber
AND    items.itemlost = 0
AND    categories.overduenoticerequired=1 
AND    branches.branchcode = issues.branchcode
AND    TO_DAYS($date)-TO_DAYS(issues.date_due) >= 0
END_SQL
                if ($branchcode) {
                    if ( C4::Context->preference('BookMobileSupportEnabled') && !C4::Context->preference('BookMobileStationOverdueRulesActive')) {
                        $borrower_sql .= 'AND ( branches.branchcode = ? OR branches.mobilebranch = ? )';
                        push @borrower_parameters, $branchcode, $branchcode;
                    } else {
                        $borrower_sql .= 'AND branches.branchcode = ?';
                        push @borrower_parameters, $branchcode;
                    }
                }
                if ( $overdue_rules->{categorycode} ) {
                    $borrower_sql .= ' AND owner.categorycode=? ';
                    push @borrower_parameters, $overdue_rules->{categorycode};
                }
            }
            $borrower_sql .= ' ORDER BY borrowernumber';

            # $sth gets borrower info if at least one overdue item has triggered the overdue action.
	        my $sth = $dbh->prepare($borrower_sql);
            $sth->execute(@borrower_parameters);

            if ( $verbose > 1 ){
                warn sprintf "--------Borrower SQL------\n";
                warn $borrower_sql . "\n $branchcode | " . $overdue_rules->{'categorycode'} . "\n ($mindays, $maxdays, ".  $date_to_run->datetime() .")\n";
                warn sprintf "--------------------------\n";
            }
            $verbose and warn sprintf "Found %s borrowers with overdues\n", $sth->rows;
            my $borrowernumber;
            while ( my $data = $sth->fetchrow_hashref ) {
                $verbose and warn "borrower ", $data->{'borrowernumber'}, ", issue of branch: ", $data->{branchcode}, ", current level $i: previous claim level ", $data->{claim_level}, ", issue claim date " , $data->{claim_date} , " and date to run " , $date_to_run->ymd() , "\n";
                
                # check the borrower has at least one item that matches
                my $days_between;
                if ( C4::Context->preference('OverdueNoticeCalendar') )
                {
                    $calendar =
                      Koha::Calendar->new( branchcode => $data->{branchcode} );
                    $days_between =
                      $calendar->days_between( dt_from_string($data->{date_due}),
                        $date_to_run );
                }
                else {
                    $days_between =
                      $date_to_run->delta_days( dt_from_string($data->{date_due}) );
                }
                $days_between = $days_between->in_units('days');
                if ($triggered) {
                    if ( $mindays != $days_between ) {
                        next;
                    }
                }
                elsif ( $checkPreviousClaimLevel )
                {
                    unless ( $data->{claim_level} == ($i-1) 
                        && $days_between >= $mindays 
                        && ($data->{claim_date} cmp $date_to_run->ymd()) == -1 ) {
                        next;
                    }
                }
                else {
                    unless (   $days_between >= $mindays
                        && $days_between <= $maxdays )
                    {
                        next;
                    }
                }
                if (defined $borrowernumber && $borrowernumber eq $data->{'borrowernumber'}){
                    # we have already dealt with this borrower
                    $verbose and warn "already dealt with this borrower $borrowernumber";
                    next;
                }
                $borrowernumber = $data->{'borrowernumber'};
                my $borr = sprintf( "%s%s%s (%s)",
                    $data->{'surname'} || '',
                    $data->{'firstname'} && $data->{'surname'} ? ', ' : '',
                    $data->{'firstname'} || '',
                    $borrowernumber );
                $verbose and warn "borrower $borr has items triggering level $i.\n";

                my $patron = Koha::Patrons->find( $borrowernumber );
                
                # check whether the borrower is a family card member                
                my $familyCardOwner = $patron->get_family_card_id;

                @emails_to_use = ();
                my $notice_email = $patron->notice_email_address;
                $notice_email =~ s/^\s+// if ($notice_email);
                $notice_email =~ s/\s+$// if ($notice_email);
                
                if ( !$notice_email && $familyCardOwner && $patron->get_age() < 18 ) {
                    $notice_email = Koha::Patrons->find( $familyCardOwner )->notice_email_address;
                }
                unless ($nomail) {
                    if (@emails) {
                        foreach (@emails) {
                            push @emails_to_use, $data->{$_} if ( $data->{$_} );
                        }
                    }
                    else {
                        push @emails_to_use, $notice_email if ($notice_email);
                    }
                }

                my $letter = Koha::Notice::Templates->find_effective_template(
                    {
                        module     => 'circulation',
                        code       => $overdue_rules->{"letter$i"},
                        branchcode => $usebranch,
                        lang       => $patron->lang
                    }
                );

                unless ($letter) {
                    $verbose and warn qq|Message '$overdue_rules->{"letter$i"}' content not found|;

                    # might as well skip while PERIOD, no other borrowers are going to work.
                    # FIXME : Does this mean a letter must be defined in order to trigger a debar ?
                    next PERIOD;
                }
                
                my @params = ($borrowernumber, $branchcode);
                @params = ($borrowernumber, $borrowernumber, $branchcode) if ( $familyCardMemberOverdueReceiverSelect );
                
                if ( C4::Context->preference('BookMobileSupportEnabled') && !C4::Context->preference('BookMobileStationOverdueRulesActive')) {
                    push(@params,$branchcode);
                }

                $sth2->execute(@params);
                my $itemcount = 0;
                my @titles = ();
                my @items = ();

                # loop through all outstanding items of the borrower and check whether
                # the overdue rules and settings apply to the current level
                my $j = 0;
                while ( my $item_info = $sth2->fetchrow_hashref() ) {
                    my $titleinfo = "";
                    
                    if ( C4::Context->preference('OverdueNoticeCalendar') ) {
                        $calendar =
                          Koha::Calendar->new( branchcode => $item_info->{issuebranch} );
                        $days_between =
                          $calendar->days_between(
                            dt_from_string( $item_info->{date_due} ), $date_to_run );
                    }
                    else {
                        $days_between =
                          $date_to_run->delta_days(
                            dt_from_string( $item_info->{date_due} ) );
                    }
                    $days_between = $days_between->in_units('days');
                    
                    # if the configuration fits to a matching a fee rule
                    # we need to write a claim fee foreach item
                    my $new_overdue_item = 0;
                       
                    if ($listall) {
                        unless ($days_between >= 1 and $days_between <= $MAX){
                            next;
                        }
                        if ( $triggered ) {
                              $new_overdue_item = 1 if ( $mindays == $days_between );
                        }
                        elsif ( $checkPreviousClaimLevel )
                        {
                            if ( $item_info->{claim_level} == ($i-1) 
                                && $days_between >= $mindays 
                                && ($item_info->{claim_date} cmp $date_to_run->ymd()) == -1 ) 
                            {
                                $new_overdue_item = 1;
                            }
                        }
                        else {
                            $new_overdue_item = 1 
                                if ($days_between >= $mindays && $days_between <= $maxdays);
                        }
                    }
                    
                    else {
                        if ($triggered) {
                            if ( $mindays != $days_between ) {
                                next;
                            }
                        }
                        elsif ( $checkPreviousClaimLevel )
                        {
                            unless ( $item_info->{claim_level} == ($i-1) 
                                && $days_between >= $mindays 
                                && ($item_info->{claim_date} cmp $date_to_run->ymd()) == -1 ) 
                            {
                                next;
                            }
                        }
                        else {
                            unless ( $days_between >= $mindays
                                && $days_between <= $maxdays )
                            {
                                next;
                            }
                        }
                        $new_overdue_item = 1;
                    }

                    $j++;
                    
                    my @item_info = map { $_ =~ /^date|date$/ ?
                                           eval { output_pref( { dt => dt_from_string( $item_info->{$_} ), dateonly => 1 } ); }
                                           :
                                           $item_info->{$_} || '' } @item_content_fields;
                    $titleinfo = join("\t", @item_info) . "\n";
                    push @titles, $titleinfo;

                    $itemcount++;
                    push @items, $item_info;
                                      
                    if ( $overdue_rules->{"debarred$i"} && !exists($debarredPatrons{$item_info->{'borrowernumber'}}) ) {
                        #action taken is debarring
                        if (! $test_mode ) {
                            AddUniqueDebarment(
                                {
                                    borrowernumber => $item_info->{'borrowernumber'},
                                    type           => 'OVERDUES',
                                    comment => "OVERDUES_PROCESS " .  output_pref( dt_from_string() ),
                                }
                            );
                        }
                        $debarredPatrons{$item_info->{'borrowernumber'}} = 1;
                        $verbose and warn "debarring borrower $item_info->{'borrowernumber'}\n";
                    }
                    
                    # check whether there are claiming fee rules defined
                    if ( $nocharge==0 && $new_overdue_item == 1 && $claimFees->checkForClaimingRules() == 1 ) {
                        # check whether there is a matching claiming fee rule
                        my $claimFeeRule = $claimFees->getFittingClaimingRule($patron->categorycode, $item_info->{itype}, $usebranch);
                        
                        if ( $claimFeeRule ) {
                            my $fee = 0.0;
                            # now that we found a matching claim fee rule, we still need to check whether there is a fee > 0 to assign
                            eval '$fee = $claimFeeRule->claim_fee_level'.$i.'()';
                            
                            if ( $fee && $fee > 0.0 ) {
                                # Bad for the patron, staff has assigned a claim fee for the item
                                # We need to write a claim fee to accountlines
                                
                                $claimFees->AddClaimFee( 
                                    {
                                        issue_id       => $item_info->{'issue_id'},
                                        itemnumber     => $item_info->{'itemnumber'},
                                        borrowernumber => $item_info->{'borrowernumber'},
                                        amount         => $fee,
                                        due            => $item_info->{date_due},
                                        claimlevel     => $i,
                                        due_since_days => $days_between,
                                        branchcode     => $usebranch,
                                        
                                        # these are parameters that we need for fancy message printing
                                        items          => [$item_info],
                                        substitute     => { bib             => $library->branchname,
                                                            'items.content' => $titleinfo,
                                                            'count'         => 1,
                                                           },
                                    }
                                );
                            }
                        }
                    }
                    
                    # store information that the item was claimed 
                    if ( $new_overdue_item ) {
                        Koha::OverdueIssue->new(
                            {
                                issue_id        => $item_info->{'issue_id'},
                                claim_level     => $i,
                                claim_time      => output_pref( { dt => $date_to_run, dateonly => 0, dateformat => 'iso' } )
                            } )->store();
                    }
                    
                } # end item loop
                $sth2->finish;

                my @message_transport_types = @{ GetOverdueMessageTransportTypes( $branchcode, $overdue_rules->{categorycode}, $i) };
                @message_transport_types = @{ GetOverdueMessageTransportTypes( $library->mobilebranch, $overdue_rules->{categorycode}, $i) }
                    if ( $library->mobilebranch && (!@message_transport_types || !C4::Context->preference('BookMobileStationOverdueRulesActive') ) );
                @message_transport_types = @{ GetOverdueMessageTransportTypes( q{}, $overdue_rules->{categorycode}, $i) }
                    unless @message_transport_types;


                my @allitems = @items;
                
                my $print_sent = 0; # A print notice is not yet sent for this patron
                
                # now we loop trough the list of message_transport_types defined for the letter
                # there might be multiple transport types activated
                for my $mtt ( @message_transport_types ) {
                
                    my $titles = join("",@titles);
                    @items = @allitems;

                    next if $mtt eq 'itiva';
                    my $effective_mtt = $mtt;
                    if ( ($mtt eq 'email' and not scalar @emails_to_use) or ($mtt eq 'sms' and not $data->{smsalertnumber}) ) {
                        # email or sms is requested but not exist, do a print.
                        $effective_mtt = 'print';
                    }
                    
                    if ( $PrintNoticesMaxLines && $effective_mtt eq 'print' && $itemcount > $PrintNoticesMaxLines ) {
                        $itemcount = $PrintNoticesMaxLines;
                        my $lastind = $itemcount-1;
                        @items = @allitems[0..$lastind];
                        $titles = join("",@titles[0..$lastind]);
                    }
                    
                    my $noticefee;
                    
                    # check whether there is notice fee rule matching
                    # if so, set the the notice fee
                    unless ( $effective_mtt eq 'print' and $print_sent == 1 ) {
                        # check whether there are notice fee rules defined
                        if ( $nocharge == 0 && $noticeFees->checkForNoticeFeeRules() == 1) {
                            #check whether there is a matching notice fee rule
                            my $noticeFeeRule = $noticeFees->getNoticeFeeRule($usebranch, $overdue_rules->{categorycode}, $effective_mtt, $overdue_rules->{"letter$i"} );
                            if ( $noticeFeeRule ) {
                                $noticefee = $noticeFeeRule->notice_fee();
                                if ( $noticefee && $noticefee > 0.0 ) {
                                    # Bad for the patron, staff has assigned a notice fee for sending the notification
                                    $noticeFees->AddNoticeFee( 
                                        {
                                            borrowernumber    => $borrowernumber,
                                            amount            => $noticefee,
                                            letter_code       => $overdue_rules->{"letter$i"},
                                            letter_date       => output_pref( { dt => dt_from_string, dateonly => 1 } ),
                                            claimlevel        => $i,
                                            branchcode        => $usebranch,
                                            
                                            # these are parameters that we need for fancy message printig
                                            substitute     => {    # this appears to be a hack to overcome incomplete features in this code.
                                                                    bib             => $library->branchname, # maybe 'bib' is a typo for 'lib<rary>'?
                                                                    'items.content' => $titles,
                                                                    'count'         => 1,
                                                                   },
                                            items          => \@items
                                        }
                                     );
                                }
                            }
                        }
                    }

                    my $letter_exists = Koha::Notice::Templates->find_effective_template(
                        {
                            module     => 'circulation',
                            code       => $overdue_rules->{"letter$i"},
                            message_transport_type => $effective_mtt,
                            branchcode => $usebranch,
                            lang       => $patron->lang
                        }
                    );

                    my $letter = parse_overdues_letter(
                        {   letter_code       => $overdue_rules->{"letter$i"},
                            borrowernumber    => $borrowernumber,
                            family_card_owner => $familyCardOwner,
                            branchcode        => $usebranch,
                            notice_fee        => $noticefee,
                            items             => \@items,
                            substitute        => {    # this appears to be a hack to overcome incomplete features in this code.
                                                bib             => $library->branchname, # maybe 'bib' is a typo for 'lib<rary>'?
                                                'items.content' => $titles,
                                                'count'         => $itemcount,
                                               },
                            # If there is no template defined for the requested letter
                            # Fallback on the original type
                            message_transport_type => $letter_exists ? $effective_mtt : $mtt,
                        }
                    );
                    unless ($letter && $letter->{content}) {
                        $verbose and warn qq|Message '$overdue_rules->{"letter$i"}' content not found|;
                        # this transport doesn't have a configured notice, so try another
                        next;
                    }

                    # The following message is not internationalized. 
                    # Thats why we skip the message.
                    #if ( $exceededPrintNoticesMaxLines ) {
                    #  $letter->{'content'} .= "List too long for form; please check your account online for a complete list of your overdue items.";
                    #}

                    # my @misses = grep { /./ } map { /^([^>]*)[>]+/; ( $1 || '' ); } split /\</, $letter->{'content'};
                    # if (@misses) {
                        # $verbose and warn "The following terms were not matched and replaced: \n\t" . join "\n\t", @misses;
                    # }

                    if ($nomail) {
                        push @output_chunks,
                          prepare_letter_for_printing(
                          {   letter         => $letter,
                              borrowernumber => $borrowernumber,
                              firstname      => $data->{'firstname'},
                              lastname       => $data->{'surname'},
                              address1       => $data->{'address'},
                              address2       => $data->{'address2'},
                              city           => $data->{'city'},
                              phone          => $data->{'phone'},
                              cardnumber     => $data->{'cardnumber'},
                              branchname     => $library->branchname,
                              letternumber   => $i,
                              postcode       => $data->{'zipcode'},
                              country        => $data->{'country'},
                              email          => $notice_email,
                              itemcount      => $itemcount,
                              titles         => $titles,
                              outputformat   => defined $csvfilename ? 'csv' : defined $htmlfilename ? 'html' : defined $text_filename ? 'text' : '',
                            }
                          );
                    } else {
                        if ( ($mtt eq 'email' and not scalar @emails_to_use) or ($mtt eq 'sms' and not $data->{smsalertnumber}) ) {
                            push @output_chunks,
                              prepare_letter_for_printing(
                              {   letter         => $letter,
                                  borrowernumber => $borrowernumber,
                                  firstname      => $data->{'firstname'},
                                  lastname       => $data->{'surname'},
                                  address1       => $data->{'address'},
                                  address2       => $data->{'address2'},
                                  city           => $data->{'city'},
                                  postcode       => $data->{'zipcode'},
                                  country        => $data->{'country'},
                                  email          => $notice_email,
                                  itemcount      => $itemcount,
                                  titles         => $titles,
                                  outputformat   => defined $csvfilename ? 'csv' : defined $htmlfilename ? 'html' : defined $text_filename ? 'text' : '',
                                }
                              );
                        }
                        unless ( $effective_mtt eq 'print' and $print_sent == 1 ) {                            
                            # Just sent a print if not already done.
                            C4::Letters::EnqueueLetter(
                                {   letter                 => $letter,
                                    borrowernumber         => $borrowernumber,
                                    message_transport_type => $effective_mtt,
                                    from_address           => $admin_email_address,
                                    to_address             => join(',', @emails_to_use),
                                    branchcode             => $usebranch,
                                    reply_address          => $library->inbound_email_address,
                                }
                            ) unless $test_mode;
                            # A print notice should be sent only once per overdue level.
                            # Without this check, a print could be sent twice or more if the library checks sms and email and print and the patron has no email or sms number.
                            $print_sent = 1 if $effective_mtt eq 'print';
                        }
                    }
                }
            }
            $sth->finish;
        }
    }

    if (@output_chunks) {
        if ( defined $csvfilename ) {
            print $csv_fh @output_chunks;        
        }
        elsif ( defined $htmlfilename ) {
            print $fh @output_chunks;        
        }
        elsif ( defined $text_filename ) {
            print $fh @output_chunks;        
        }
        elsif ($nomail){
                local $, = "\f";    # pagebreak
                print @output_chunks;
        }
        # Generate the content of the csv with headers
        my $content;
        if ( defined $csvfilename ) {
            my $delimiter = C4::Context->csv_delimiter;
            $content = join($delimiter, qw(title name surname address1 address2 zipcode city country email itemcount itemsinfo due_date issue_date)) . "\n";
            $content .= join( "\n", @output_chunks );
        } elsif ( defined $htmlfilename ) {
            $content = _get_html_start();
            $content .= join( "\n", @output_chunks );
            $content .= _get_html_end();
        } else {
            $content = join( "\n", @output_chunks );
        }

        if ( C4::Context->preference('EmailOverduesNoEmail') ) {
            my $attachment = {
                filename => defined $csvfilename ? 'attachment.csv' : defined $htmlfilename ? 'attachment.html' : 'attachment.txt',
                type => defined $htmlfilename ? 'text/html' : 'text/plain',
                content => $content,
            };

            my $letter = {
                title   => 'Overdue Notices',
                content => 'These messages were not sent directly to the patrons.',
            };

            C4::Letters::EnqueueLetter(
                {   letter                 => $letter,
                    borrowernumber         => undef,
                    message_transport_type => 'email',
                    attachments            => [$attachment],
                    to_address             => $branch_email_address,
                    branchcode             => $usebranch,
                }
            ) unless $test_mode;
        }
    }

}
if ($csvfilename) {
    # note that we're not testing on $csv_fh to prevent closing
    # STDOUT.
    close $csv_fh;
}

if ( defined $htmlfilename ) {
  print $fh _get_html_end();
  close $fh;
} elsif ( defined $text_filename ) {
  close $fh;
}

=head1 INTERNAL METHODS

These methods are internal to the operation of overdue_notices.pl.

=head2 prepare_letter_for_printing

returns a string of text appropriate for printing in the event that an
overdue notice will not be sent to the patron's email
address. Depending on the desired output format, this may be a CSV
string, or a human-readable representation of the notice.

required parameters:
  letter
  borrowernumber

optional parameters:
  outputformat

=cut

sub prepare_letter_for_printing {
    my $params = shift;

    return unless ref $params eq 'HASH';

    foreach my $required_parameter (qw( letter borrowernumber )) {
        return unless defined $params->{$required_parameter};
    }

    my $return;
    chomp $params->{titles};
    if ( exists $params->{'outputformat'} && $params->{'outputformat'} eq 'csv' ) {
        if ($csv->combine(
                $params->{'firstname'}, $params->{'lastname'}, $params->{'address1'},  $params->{'address2'}, $params->{'postcode'},
                $params->{'city'}, $params->{'country'}, $params->{'email'}, $params->{'phone'}, $params->{'cardnumber'},
                $params->{'itemcount'}, $params->{'titles'}, $params->{'branchname'}, $params->{'letternumber'}
            )
          ) {
            return $csv->string, "\n";
        } else {
            $verbose and warn 'combine failed on argument: ' . $csv->error_input;
        }
    } elsif ( exists $params->{'outputformat'} && $params->{'outputformat'} eq 'html' ) {
      $return = "<pre>\n";
      $return .= "$params->{'letter'}->{'content'}\n";
      $return .= "\n</pre>\n";
    } else {
        $return .= "$params->{'letter'}->{'content'}\n";

        # $return .= Data::Dumper->Dump( [ $params->{'borrowernumber'}, $params->{'letter'} ], [qw( borrowernumber letter )] );
    }
    return $return;
}

=head2 _get_html_start

Return the start of a HTML document, including html, head and the start body
tags. This should be usable both in the HTML file written to disc, and in the
attachment.html sent as email.

=cut

sub _get_html_start {

    return "<html>
<head>
<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />
<style type='text/css'>
pre {page-break-after: always;}
pre {white-space: pre-wrap;}
pre {white-space: -moz-pre-wrap;}
pre {white-space: -o-pre-wrap;}
pre {word-wrap: break-work;}
</style>
</head>
<body>";

}

=head2 _get_html_end

Return the end of an HTML document, namely the closing body and html tags.

=cut

sub _get_html_end {

    return "</body>
</html>";

}

cronlogaction({ action => 'End', info => "COMPLETED" });
