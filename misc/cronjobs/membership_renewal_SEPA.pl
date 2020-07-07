#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright (C) 2020 LMSCloud GmbH
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

membership_renewal.pl - cron script for renewal of soon ending memberships and payment of resulting enrolment fees via SEPA direct debit

=head1 SYNOPSIS

./membership_renewal.pl -c

=head1 DESCRIPTION

This script renews the membership of patrons that have agreed to payment of resulting enrolment fees via SEPA direct debit.
The relevant data for the SEPA direct debit are stored in table borrower_attributes.
The resulting XML file containing the SEPA direct debit information for the new enrolment fees is transferred manually by staff to the bank of the library.
It is stored in the standard 'batchprint' directory and named in the form pain.008.yyyymmdd.

=head1 OPTIONS

=over 8

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<-v>

Verbose. Without this flag set, only fatal errors are reported.

=item B<-n>

Do not send any email. SEPA direct debit announcements that would have been sent to
the patrons are printed to standard out.

=item B<-c>

Confirm flag: Add this option. The script will only print a usage
statement otherwise.

=item B<-action>

Optional action selector, may contain 'renewal' or 'sepaDirectDebit (also in combination).
Default: renewalsepaDirectDebit

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
'SepaDirectDebitRemittanceInfo': Text used in XML file containing SEPA direct debits for XML-element <PmtInf><MsgId><RmtInf><Ustrd>.
'SepaDirectDebitBorrowerNoticeLettercode': Default lettercode of note sent to patron informing about the upcoming SEPA direct debit for the membership fee.
'SepaDirectDebitCashRegisterName', 'SEPA', NULL, 'Name of cash register for assignment of the SEPA direct debit payments.', 'Free' ),
'SepaDirectDebitCashRegisterManagerCardnumber', '672555551', NULL, 'Cardnumber of the staff account that is used for booking SEPA direct debit in the specially provided cash register.', 'Free' )

Relevant borrowerattributes:
'SEPA': Trigger if the patron has aggreed to payment of membership fee by SEPA direct debit (type:YesNo).
'SEPA_BIC': BIC of the patron's bank account used in XML file containing SEPA direct debits.
'SEPA_IBAN': IBAN of the patron's bank account used in XML file containing SEPA direct debits.
'SEPA_Sign': Date when the patron signed the SEPA direct debit mandate.

The content of the SEPA direct debit announcement email is configured in Tools -> Notices and slips. Use the MEMBERSHIP_SEPA_NOTE notice as default.

These emails are staged in the outgoing message queue, as are messages
produced by other features of Koha. This message queue must be
processed regularly by the
F<misc/cronjobs/process_message_queue.pl> program.

In the event that the C<-n> flag is passed to this program, no emails
are sent. Instead, messages are sent on standard output from this
program.

Notices can contain placeholder variables enclosed in double angle brackets like
E<lt>E<lt>thisE<gt>E<gt>. Those placeholder variables will be replaced with values
specific to the member whose membership has been renewed.
Available variables are:

=over

=item E<lt>E<lt>borrowers.*E<gt>E<gt>

any field from the borrowers table

=item E<lt>E<lt>branches.*E<gt>E<gt>

any field from the branches table

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

#binmode( STDIN, ":utf8" );
#binmode( STDOUT, ":utf8" );
#binmode( STDERR, ":utf8" );

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
    my $expiringMemberships = $sepaPayment->renewMembershipForSEPADebitPatrons(
        {
            ( $branch ? ( 'me.branchcode' => $branch ) : () ),
            expiryAfterDays => $expiryAfterDays,
            expiryBeforeDays => $expiryBeforeDays,
        }
    );
    warn 'membership_renewal.pl: sepaPayment->renewMembershipForSEPADebitPatrons() tried to renew ' . $expiringMemberships->count . ' soon expiring memberships.' if $verbose;
}

if ( index($action, 'sepaDirectDebit') >= 0 ) {
    # action: 'pay' enrolment fee via SEPA direct debit and create the corresponding XML file that can be transferred manually to the library's bank.
    warn 'membership_renewal.pl: Trying to pay open fees for membership renewals for patrons with activated SEPA direct debit.' if $verbose;
    my $success = $sepaPayment->payMembershipFeesForSEPADebitPatrons(
        {
            ( $branch ? ( 'branchcode' => $branch ) : () ),
            sepaDirectDebitDelayDays => $sepaDirectDebitDelayDays,
        }
    );
    warn "membership_renewal.pl: sepaPayment->payMembershipFeesForSEPADebitPatrons() success:$success:" if $verbose;
}



