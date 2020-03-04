#!/usr/bin/perl

# Copyright 2016 LMSCloud GmbH
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

# runBatchJobs.pl
#
# Start batch jobs via user interface
# Runs scripts by forking the process and execturing the batch jobs

use Modern::Perl;
use File::Spec;
use CGI qw ( -utf8 );
use C4::Auth;
use C4::Koha;
use C4::Output;
use Koha::Patron::Categories;
use Time::HiRes qw(time);
use DateTime;
use Time::localtime;
use Koha::DateUtils;
use Proc::Daemon;
use C4::Context;


my $input = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => "tools/runBatchJob.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { tools => "run_batch_programs" },
    }
);

my %cookies   = parse CGI::Cookie($cookie);
my $sessionID = $cookies{'CGISESSID'}->value;
my $dbh       = C4::Context->dbh;

my $cmd = $input->param('cmd') || '';
my $op  = $input->param('op') || '';

my $runCmd = '';

my $err = '';

my $cronbindir = '/usr/share/koha/bin/cronjobs/';

my $batchlogdir = File::Spec->catpath( "", C4::Context->config('logdir'), "batch" );
if (! -e "$batchlogdir") {
    mkdir $batchlogdir, 0744;
}

my $logcmd;

if ( $op eq 'progress' ) {
    my $filenamepart = $input->param('filenamepart') || '';
    
    my ($outfile,$cmdfile,$pidfile,$filename) = getOutputFileNames($batchlogdir,$filenamepart);
    
    my $status = 'completed';
    
    my $pid = subGetFileContent($pidfile);
    $pid =~ s/[^0-9]//g if ( $pid );
    
    if ( $pid ) {
        my $procexists = kill 0, $pid;
        if ( $procexists ) {
            $status = 'running';
        }
    }
    
    $template->param( pid => $pid, status => $status, outfilecontent =>  subGetFileContent($outfile), filenamepart => $filenamepart );
}
elsif ( $op eq 'run' ) {
    if ( $cmd eq 'fines' ) {
        $runCmd = getExecPath($cronbindir, "fines.pl",'-v');
        $logcmd = $runCmd;
    }
    elsif ( $cmd eq 'gather_print_notices' ) {
        $runCmd = getExecPath($cronbindir, "gather_print_notices.pl");
            
        my $outputformat = $input->param('gather_print_notices_output_form') || 'html';
        if ( $outputformat =~ /^(html|ods|csv)$/ ) {
            $runCmd .= ' --' . $outputformat;
        }
        
        my $splitoutput = $input->param('gather_print_notices_output_split') || '';
        if ( $splitoutput && $splitoutput eq 'yes' ) {
            $runCmd .= ' -s';
        }
        
        my $splitbylettercode = $input->param('gather_print_notices_output_splitcode') || '';
        if ( $splitbylettercode && $splitbylettercode eq 'yes' ) {
            $runCmd .= ' -sc';
        }
        
        my $setsent = $input->param('gather_print_notices_output_sent') || '';
        if ( $setsent && $setsent eq 'no' ) {
            $runCmd .= ' --nosend';
        }
        else {
            $runCmd .= ' --send';
        }
        
        my $lettercode = $input->param('gather_print_notices_letter_code') || '';
        if ( $lettercode ) {
            $runCmd .= ' --letter_code=' . $lettercode;
        }
        
        my $email = $input->param('gather_print_notices_email') || '';
        if ( $email ) {
            $runCmd .= ' --email="' . $email . '"';
        }
        
        my $outputdir = C4::Context->config('outputdownloaddir');
        if (! -e "$outputdir") {
            mkdir $outputdir, 0744;
        }
        
        $outputdir = File::Spec->catpath( "", $outputdir, "batchprint" );
        if (! -e "$outputdir") {
            mkdir $outputdir, 0744;
        }
        
        $runCmd .= " $outputdir";
        
        $logcmd = $runCmd;
    }
    elsif ( $cmd eq 'advance_notices' ) {
        $runCmd = getExecPath($cronbindir, "advance_notices.pl",'-c -v');
        my $maxdays = $input->param('advance_notices_maxdays') || '';
        if ( $maxdays && $maxdays =~ /^[0-9]+$/ && $maxdays >= 0 ) {
            $runCmd .= ' -m ' . $maxdays;
        }
        $logcmd = $runCmd;
    }
    elsif ( $cmd eq 'membership_expiry' ) {
        $runCmd = getExecPath($cronbindir, "membership_expiry.pl", "-c -v");
        
        my $membership_expiry_form = $input->param('membership_expiry_form') || '';
        if ( $membership_expiry_form ) {
            $runCmd .= ' -letter=' . $membership_expiry_form;
        }
        
        my $membership_expiry_before = $input->param('membership_expiry_before') || '';
        if ( $membership_expiry_before && $membership_expiry_before =~ /^[0-9]+$/ ) {
            $runCmd .= ' -before=' . $membership_expiry_before;
        }
        my $membership_expiry_after = $input->param('membership_expiry_after') || '';
        if ( $membership_expiry_after && $membership_expiry_after =~ /^[0-9]+$/ ) {
            $runCmd .= ' -after=' . $membership_expiry_after;
        }
        
        my $membership_expiry_branch = $input->param('membership_expiry_branch') || '';
        if ( $membership_expiry_branch ) {
            $runCmd .= ' -branch=' . $membership_expiry_branch;
        }
        
        $logcmd = $runCmd;
    }
    elsif ( $cmd eq 'overdue_notices' ) {
        $runCmd = getExecPath($cronbindir, "overdue_notices.pl",'-v');
        
        my $overdue_notices_branch = $input->param('overdue_notices_branch') || '';
        if ( $overdue_notices_branch ) {
            $runCmd .= ' -library ' . $overdue_notices_branch;
        }
        
        my $overdue_notices_nomail = $input->param('overdue_notices_nomail') || '';
        if ( $overdue_notices_nomail &&  $overdue_notices_nomail eq 'yes' ) {
            $runCmd .= ' -n';
        }
        
        my $overdue_notices_output_format = $input->param('overdue_notices_nomail') || '';
        if ( $overdue_notices_output_format ) {
            if ( $overdue_notices_output_format eq 'html' || $overdue_notices_output_format eq 'text' || $overdue_notices_output_format eq 'csv' ) {
                my $outputdir = C4::Context->config('outputdownloaddir');
                if (! -e "$outputdir") {
                    mkdir $outputdir, 0744;
                }

                $outputdir = File::Spec->catpath( "", $outputdir, "batchprint" );
                if (! -e "$outputdir") {
                    mkdir $outputdir, 0744;
                }
                my $today = DateTime->now(time_zone => C4::Context->tz );
                $outputdir = File::Spec->catdir( $outputdir, "notices-".$today->ymd().".csv" ) if ( $overdue_notices_output_format eq 'csv' );
                $runCmd .= " -$overdue_notices_output_format $outputdir" ;
            }
        }
        
        my $overdue_notices_max_days = $input->param('overdue_notices_max_days') || '';
        if ( $overdue_notices_max_days && $overdue_notices_max_days  =~ /^[0-9]+$/ && $overdue_notices_max_days > 0 ) {
            $runCmd .= " -max $overdue_notices_max_days";
        }
        
        my @overdue_notices_groups = $input->param('overdue_notices_groups');
        if ( scalar(@overdue_notices_groups) > 0 ) {
            my @groups = ();
            foreach my $group (@overdue_notices_groups) {
                if ( $group eq '---all---' ) {
                    @groups = ();
                    last;
                }
                push @groups, $group;
            }
            foreach my $group (@groups) {
                $runCmd .= " -borcat $group";
            }
        }
        
        my $overdue_notices_listall = $input->param('overdue_notices_listall') || '';
        if ( $overdue_notices_listall && $overdue_notices_listall eq 'yes' ) {
            $runCmd .= " -list-all";
        }
        
        my $overdue_notices_triggered = $input->param('overdue_notices_triggered') || '';
        if ( $overdue_notices_triggered && $overdue_notices_triggered eq 'yes' ) {
            $runCmd .= " -t ";
        }
        
        my $overdue_notices_senddate = $input->param('overdue_notices_senddate') || '';
        if ( $overdue_notices_senddate ) {
            $overdue_notices_senddate = dt_from_string( $overdue_notices_senddate );
            $overdue_notices_senddate = output_pref({dt => $overdue_notices_senddate, dateonly => 1, dateformat => 'iso', });
            $runCmd .= ' -date ' . $overdue_notices_senddate;
        }
        
        $logcmd = $runCmd;
    }
    elsif ( $cmd eq 'process_message_queue' ) {
        $runCmd = getExecPath($cronbindir, "process_message_queue.pl",'-v');
        $logcmd = $runCmd;
    }
    elsif ( $cmd eq 'batch_anonymise' ) {
        $runCmd = getExecPath($cronbindir, "batch_anonymise.pl",'-v');
        my $days = $input->param('batch_anonymise_days') || '';
        if ( $days && $days =~ /^[0-9]+$/ && $days >= 0 ) {
            $runCmd .= ' --days ' . $days;
        }
        else {
            $runCmd = '';
        }
        $logcmd = $runCmd;
    }
    elsif ( $cmd eq 'delete_patrons' ) {
        $runCmd = getExecPath($cronbindir, "delete_patrons.pl",'-c -v');
        my $inactive_since = $input->param('delete_patrons_not_borrowed_since') || '';
        if ( $inactive_since ) {
            $inactive_since = dt_from_string( $inactive_since );
            $inactive_since = output_pref({dt => $inactive_since, dateonly => 1, dateformat => 'iso', });
            $runCmd .= ' --not_borrowed_since=' . $inactive_since;
        }
        my $expired_before = $input->param('delete_patrons_expired_before') || '';
        if ( $expired_before ) {
            $expired_before = dt_from_string( $expired_before );
            $runCmd .= ' --expired_before=' . output_pref({dt => $expired_before, dateonly => 1, dateformat => 'iso', });
        }
        
        if ( (! $expired_before) && (! $inactive_since) ) {
            $err = 'NO_DATE_PROVIDED_FOR_DELETE_PATRON';
            $runCmd = '';
        }
        $logcmd = $runCmd;
    }
    elsif ( $cmd eq 'juv2adult' ) {
        $runCmd = getExecPath($cronbindir, "j2a.pl", "-v");
        
        my $juv2adult_from = $input->param('juv2adult_from') || '';
        if ( $juv2adult_from ) {
            $runCmd .= ' -f ' . $juv2adult_from;
        }
        
        my $juv2adult_to = $input->param('juv2adult_to') || '';
        if ( $juv2adult_to ) {
            $runCmd .= ' -t ' . $juv2adult_to;
        }
        
        my $juv2adult_branch = $input->param('juv2adult_branch') || '';
        if ( $juv2adult_branch ) {
            $runCmd .= ' -b ' . $juv2adult_branch;
        }
        my $juv2adult_simulate = $input->param('juv2adult_simulate') || '';
        if ( $juv2adult_simulate && $juv2adult_simulate eq 'yes' ) {
            $runCmd .= ' -n';
        }
        
        $logcmd = $runCmd;
    }
    elsif ( $cmd eq 'notice_unprocessed_suggestions' ) {
        $runCmd = getExecPath($cronbindir, "notice_unprocessed_suggestions.pl",'-c -v');
        my $days = $input->param('notice_unprocessed_suggestions_days') || '';
        if ( $days && $days =~ /^[0-9]+$/ && $days >= 0 ) {
            $runCmd .= ' --days ' . $days;
        }
        else {
            $runCmd = '';
        }
        $logcmd = $runCmd;
    }
}

if ( $runCmd ne '' ) {
    my ($outfile,$cmdfile,$pidfile,$filenamepart) = getProcessOutputFiles($batchlogdir, $cmd);
    
    my $startCmd = "/usr/bin/perl $runCmd >$outfile 2>&1";
    open(my $fh, ">", $cmdfile);
    print $fh $startCmd;
    close $fh;
    # we could also do somethin like that:
    # use IPC::Run3; run3("/usr/share/bin/launchjob.pl ".$batchlogdir." ".$ddir." ".$jid." ".$cmd);
    # but for now we use the Daemon
    my $daemon = Proc::Daemon->new(
        work_dir     => $batchlogdir,
        file_umask   => '022',
        pid_file     => $pidfile,
        exec_command => $startCmd
   );
   my $pid;
   
   if ( $daemon ) {
	$pid = $daemon->Init();
   }
   
   if ( $pid ) {
       $template->param( pid => $pid, status => 'launched', outfilecontent =>  subGetFileContent($outfile), filenamepart => $filenamepart );
   }
}

$template->param( logcmd => $logcmd ) if ( $logcmd );

# get the patron categories and pass them to the template
my $categories = Koha::Patron::Categories->search({}, {order_by => ['description']});
$template->param( categories => $categories ) if ( $categories );

my $printlettercodes = GetUsedLetterCodes();
$template->param( printlettercodes => $printlettercodes ) if ( $printlettercodes );

my $membershipReminderLetters = GetLettersForCode("MEMBERSHIP_EXPIRY");
$template->param( membershipReminderLetters => $membershipReminderLetters ) if ( $membershipReminderLetters );

output_html_with_http_headers $input, $cookie, $template->output;
exit 0;

sub getExecPath {
    my $path = shift;
    my $execname = shift;
    my $intialoption = shift;
    
    my $cmd = File::Spec->catpath( "", $path, $execname );
    if ( $intialoption ) {
        $cmd .= " $intialoption";
    }
    return $cmd;
}
        
sub getProcessOutputFiles {
    my $batchdir = shift;
    my $processname = shift;

    my $time = DateTime->from_epoch( epoch => time )->strftime('%Y%m%d-%H%M%S-%6N');
    
    my $fname = "$processname-$time";
    
    return getOutputFileNames($batchdir,$fname);
}

sub getOutputFileNames {
    my $batchdir = shift;
    my $filenamepart = shift;
    
    my $outfile = "$batchdir/$filenamepart.out";
    my $cmdfile = "$batchdir/$filenamepart.cmd";
    my $pidfile = "$batchdir/$filenamepart.pid";
    
    return ($outfile,$cmdfile,$pidfile,$filenamepart);
}

sub GetUsedLetterCodes {
    my $dbh       = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT DISTINCT letter_code FROM message_queue WHERE message_transport_type = ? GROUP BY letter_code");
    $sth->execute("print");
    
    my @lettercodes;
    while ( my $lettercode = $sth->fetchrow_hashref ) {
        push @lettercodes, { lettercode => $lettercode->{'letter_code'} };
    }
    $sth->finish();

    return \@lettercodes;
}

sub GetLettersForCode {
    my $code = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT name FROM letter WHERE code = ? ORDER BY name");
    $sth->execute($code);
    
    my @letters;
    while ( my $letter = $sth->fetchrow_hashref ) {
        push @letters, { name => $letter->{'name'} };
    }
    $sth->finish();

    return \@letters;
}

sub subGetFileContent {
    my $filename = shift;
    my $content;
    
    {
        local $/ = undef;
        open(my $fh, "<:encoding(UTF-8)", $filename);
        binmode $fh;
        $content = <$fh>;
        close $fh;
        
    }
    
    return $content;
}
