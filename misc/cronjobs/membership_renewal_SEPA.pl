#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright (C) 2020-2021 LMSCloud GmbH
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

=head1 NAME

membership_renewal.pl - cron script for renewal of soon ending memberships and payment of resulting enrolment fees, and even other fines, via SEPA direct debit.

=head1 SYNOPSIS

./membership_renewal.pl -c -expiryAfterDays 0 -expiryBeforeDays 14 \ -sepaDirectDebitDelayDays 17 -action renewal_and_sepaDirectDebit

=head1 DESCRIPTION

This script features two quite independent functions: 
(A) It renews the membership of patrons that have agreed to payment of resulting enrolment fees, and maybe also other fines, via SEPA direct debit. 
(B) It exports SEPA direct debit data to an payment instruction XML file to be forwarded to the library's bank
and 'pays' the corresponding fees in Koha in advance in anticipation of the success of the SEPA direct debit that will be triggered a few days in the future, 
again only for those patrons that have agreed to this method.
The relevant data for the SEPA direct debit are stored in table borrower_attributes.
The resulting XML file containing the SEPA direct debit instructions for the new enrolment fees and other fines of configurable types 
is transferred manually by staff to the bank of the library or to the financal accounting system of the township.
It is stored in the standard 'batchprint' directory and so may be downloaded from within the Koha staff interface.
Its name is built based on the pattern in system preference 'SepaDirectDebitPaymentInstructionFileName', 
e.g. pattern pain.008.<<cc>><<yy>><<mm>><<dd>>.xml results in name pain.008.20191231.xml if the script is executed on date 2019-12-31.
The file is also created if no payment instructions have to be stored in it by the current run, but in this case '_no_transactions.xml' is appended to its name.
This is required because some external plausibility check programs deny a file containing no payment instructions, so we have to indicate this case somehow to the user.
In case of grossly wrong or lacking IBAN or BIC specification of the handled borrower an error file is created in the same directory, 
its name beeing similar to the name of the XML output file, but with '_Fehler.html' appended.


=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints this manual page and exits.

=item B<-v>

Verbose. Without this flag set, only fatal errors are reported.

=item B<-n>

Do not send any email, do not creat print tasks. SEPA direct debit notifications that would have been sent to
the patrons are printed to standard out.

=item B<-c>

Confirm flag: Add this option. The script will only print a usage
statement otherwise.

=item B<-action>

Optional action selector, may contain 'renewal' or 'sepaDirectDebit (also in combination).
Default: renewalsepaDirectDebit (equivalent to e,g. renewal_and_sepaDirectDebit)

=item B<-branch>

Optional branchcode to restrict the cronjob to that branch.

=item B<-expiryAfterDays>

Optional parameter defining the 'from date' of the dateexpiry selection period 
as current date plus this number of days. Has to be non-negative. Default value: 0

=item B<-expiryBeforeDays>

Optional parameter defining the 'until date' of the dateexpiry selection period 
as current date plus this number of days. Has to be non-negative. Default value: 14

=item B<-sepaDirectDebitDelayDays>

Optional parameter defining the RequestedCollectionDate in the XML file containing the SEPA direct debit information for the library's bank 
as current date plus this number of days. Has to be non-negative. Default value: 14

=item B<-lettercode>

Optional parameter to use another lettercode than the standard configured in systempreferences with variable='SepaDirectDebitBorrowerNoticeLettercode' .

=back

=head1 CONFIGURATION

Relevant system preferences:

'SepaDirectDebitCreditorBic': BIC of the library's bank account used in XML file containing SEPA direct debits.

'SepaDirectDebitCreditorIban: IBAN of the library's bank account used in XML file containing SEPA direct debits.

'SepaDirectDebitCreditorId: SEPA creditor ID of the library used in XML file containing SEPA direct debits.

'SepaDirectDebitCreditorName': Name of the library used in XML file containing SEPA direct debits for XML-element <PmtInf><Cdtr><Nm>.

'SepaDirectDebitInitiatingPartyName': Name of the library used in XML file containing SEPA direct debits for XML-element <GrpHdr><InitgPty><Nm> (usually uppercase).

'SepaDirectDebitMessageIdHeader': Text that, after appending the current date, will be used in XML file containing SEPA direct debits for XML-element <GrpHdr><MsgId>.

'SepaDirectDebitRemittanceInfo': Text used in XML file containing SEPA direct debits for XML-element <PmtInf><DrctDbtTxInf><RmtInf><Ustrd>.

'SepaDirectDebitBorrowerNoticeLettercode': Default lettercode of note sent to patron informing about the upcoming SEPA direct debit for the membership fee or other fines.

'SepaDirectDebitCashRegisterName': Name of cash register for assignment of the SEPA direct debit payments.

'SepaDirectDebitCashRegisterManagerCardnumber: Cardnumber of the staff account that is used for booking SEPA direct debit in the specially provided cash register.

'SepaDirectDebitAccountTypes': List of account types of fees to be paid via SEPA direct debit, separated by '|'.'

'SepaDirectDebitMinFeeSum': A SEPA direct debit will be generated only if the sum of open fees of a borrower to be paid via SEPA direct debit is greater or equal this threshold value.'

'SepaDirectDebitLocalInstrumentCode': Text used in XML file containing SEPA direct debits for <PmtInf><PmtTpInf><LclInstrm><Cd>. One of 'CORE', 'COR1'

'SepaDirectDebitPaymentInstructionFileName': Pattern for the name of the file containing the SEPA direct debit payment instructions for the bank. Placeholders: century:<<cc>> year:<<yy>> month:<<mm>> day:<<dd>>.'

Relevant borrowerattributes:

'SEPA': Trigger if the patron has aggreed to payment of membership fee by SEPA direct debit (type:YesNo).

'SEPA_BIC': BIC of the patron's bank account used in XML file containing SEPA direct debits.

'SEPA_IBAN': IBAN of the patron's bank account used in XML file containing SEPA direct debits.

'SEPA_Sign': Date when the patron signed the SEPA direct debit mandate. (not used anymore)

'Konto_von': Name of owner of the bank account used, if differing from borrower.

The content of the SEPA direct debit notification email and printed letter is configured in Tools -> Notices and slips. 
Use the MEMBERSHIP_SEPA_NOTE_CHARGE notification as default if exclusively membership fees are handled; use SEPA_NOTE_CHARGE notification if fees of different accounttype have to paid with this method.

These emails and print tasks are staged in the outgoing message queue, as are messages
produced by other features of Koha. This message queue must be
processed regularly by the
F<misc/cronjobs/process_message_queue.pl> program.

In the event that the C<-n> flag is passed to this program, no emails or print tasks are queued.
Instead, email messages and print tasks are output on standard output from this program.

The notification layouts can contain placeholder variables enclosed in double angle brackets like
E<lt>E<lt>thisE<gt>E<gt>. Those placeholder variables will be replaced with values
specific to the patron whose fees have been 'paid' in Koha.
Available variables are:

=over

=item E<lt>E<lt>borrowers.*E<gt>E<gt>

any field from the borrowers table

=item E<lt>E<lt>branches.*E<gt>E<gt>

any field from the branches table

=item E<lt>E<lt>accountlinesFee.*E<gt>E<gt>

any field from the accountlines table (paid fee of this borrower, useful only if fee type is restricted to membership renewal)

=item E<lt>E<lt>accountlinesPayment.*E<gt>E<gt>

any field from the accountlines table (payment of this borrower)

=back

=cut

use Modern::Perl;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use C4::Log;
use Koha::SEPAPayment;

binmode( STDIN, ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

# These are defaults for command line options.
my $confirm;                              # -c: Confirm that the user has read and configured this script.
my $nomail;                               # -n: No mail. Will not send any emails.
my $verbose = 0;                          # -v: verbose
my $debug = 0;                            # -d: debug (extra verbose)
my $help = 0;
my $man = 0;
my $action = 'renewalsepaDirectDebit';
my $expiryAfterDays = 0;
my $expiryBeforeDays = 14;
my $sepaDirectDebitDelayDays = 14;
my ( $branch, $lettercode );


# main
GetOptions(
    'help|?'                => \$help,
    'man'                   => \$man,
    'c'                     => \$confirm,
    'n'                     => \$nomail,
    'v'                     => \$verbose,
    'd'                     => \$debug,
    'action:s'              => \$action,
    'branch:s'              => \$branch,
    'expiryAfterDays:i'     => \$expiryAfterDays,
    'expiryBeforeDays:i'    => \$expiryBeforeDays,
    'lettercode:s'          => \$lettercode,
    'sepaDirectDebitDelayDays:i' => \$sepaDirectDebitDelayDays,
) or pod2usage(2);

pod2usage( -verbose => 2 ) if $man;
pod2usage(1) if $help || !$confirm;

warn 'membership_renewal.pl: Trying to renew upcoming membership expiries and/or create SEPA direct debits for patrons with activated SEPA direct debit.' if $verbose;
warn "membership_renewal.pl" . 
    ": action:" . (defined($action)?$action:'undef') . 
    ": expiryAfterDays:" . (defined($expiryAfterDays)?$expiryAfterDays:'undef') . 
    ": expiryBeforeDays:" . (defined($expiryBeforeDays)?$expiryBeforeDays:'undef') . 
    ": sepaDirectDebitDelayDays:" . (defined($sepaDirectDebitDelayDays)?$sepaDirectDebitDelayDays:'undef') . 
    ": branch:" . (defined($branch)?$branch:'undef') . 
    ": lettercode:" . (defined($lettercode)?$lettercode:'undef') . 
    ":" if $verbose;

cronlogaction();

my $sepaPayment = Koha::SEPAPayment->new( $debug?2:($verbose?1:0), $lettercode, $nomail );

# check if the SEPA direct debit configuration of the library is OK
my $configError = $sepaPayment->getErrorMsg();
if( $configError ) {
    #If at least one essential system preference for SEPA direct debit is not set, we will exit.
    warn "Exiting membership_renewal.pl. Error: $configError\n";
    exit;
}

if ( index($action, 'renewal') >= 0 ) {
    # action: renew membership and insert enrolment fee as required
    warn "membership_renewal.pl: Trying to renew membership for patrons with SEPA direct debit." if $verbose;
    my ( $renewMembershipCount, $renewedMembershipCount ) = $sepaPayment->renewMembershipForSepaDirectDebitPatrons(
        {
            ( $branch ? ( 'me.branchcode' => $branch ) : () ),
            expiryAfterDays => $expiryAfterDays,
            expiryBeforeDays => $expiryBeforeDays,
        }
    );
    warn 'membership_renewal.pl: sepaPayment->renewMembershipForSepaDirectDebitPatrons() tried to renew ' . $renewMembershipCount . ' soon expiring memberships, renewed ' . $renewedMembershipCount . '.' if $verbose;
}

if ( index($action, 'sepaDirectDebit') >= 0 ) {
    # action: 'pay' enrolment fee via SEPA direct debit and create the corresponding XML file that can be transferred manually to the library's bank.
    warn 'membership_renewal.pl: Trying to pay open fees for membership renewals for patrons with activated SEPA direct debit.' if $verbose;
    my $success = $sepaPayment->paySelectedFeesForSepaDirectDebitPatrons(
        {
            ( $branch ? ( 'branchcode' => $branch ) : () ),
            sepaDirectDebitDelayDays => $sepaDirectDebitDelayDays,
        }
    );
    warn "membership_renewal.pl: sepaPayment->paySelectedFeesForSepaDirectDebitPatrons() success:$success:" if $verbose;
}



