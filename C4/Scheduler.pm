package C4::Scheduler;

# Copyright 2007 Liblime Ltd
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

use C4::Context;
use Schedule::At;

our (@ISA, @EXPORT_OK);
BEGIN {
    require Exporter;
    @ISA       = qw(Exporter);
    @EXPORT_OK = qw(get_jobs get_at_jobs get_at_job add_at_job remove_at_job);
}

=head1 NAME

C4::Scheduler - Module for running jobs with the unix at command

=head1 SYNOPSIS

  use C4::Scheduler;

=head1 DESCRIPTION

=cut

=head1 METHODS

=head2 get_jobs();

This will return all scheduled jobs

=cut

sub get_jobs {
    my $jobs = get_at_jobs();
# add call to get cron jobs here too
    return ($jobs);
}

=head2 get_at_jobs();

This will return all At scheduled jobs

=cut

sub get_at_jobs {
	my %jobs = Schedule::At::getJobs();
	return (\%jobs);
}

=head2 get_at_job($id)

This will return the At job with the given id

=cut

sub get_at_job {
	my ($id)=@_;
	my %jobs = Schedule::At::getJobs(JOBID => $id);
}

=head2 add_at_job ($time,$command)

Given a timestamp and a command this will schedule the job to run at that time.

Returns true if the job is added to the queue and false otherwise.

=cut

sub add_at_job {
	my ($time,$command) = @_;
    # FIXME - a description of the task to be run 
    # may be a better tag, since the tag is displayed
    # in the job list that the administrator sees - e.g.,
    # "run report foo, send to foo@bar.com"
	Schedule::At::add(TIME => $time, COMMAND => $command, TAG => $command);

    # FIXME - this method of checking whether the job was added
    # to the queue is less than perfect:
    #
    # 1. Since the command is the tag, it is possible that there is
    #    already a job in the queue with the same tag.  However, since
    #    the tag is what displays in the job list, we can't just
    #    give it a unique ID.
    # 2. Schedule::At::add() is supposed to return a non-zero
    #    value if it fails to add a job - however, it does
    #    not check all error conditions - in particular, it does
    #    not check the return value of the "at" run; it basically
    #    complains only if it can't find at.
    # 3. Similary, Schedule::At::add() does not do something more useful,
    #    such as returning the job ID.  To be fair, it is possible
    #    that 'at' does not allow this in any portable way.
    # 4. Although unlikely, it is possible that a job could be added
    #    and completed instantly, thus dropping off the queue.
    my $job_found = 0;
    eval {
	    my %jobs = Schedule::At::getJobs(TAG => $command);
        $job_found = scalar(keys %jobs) > 0;
    };
    if ($@) {
        return 0;
    } else {
        return $job_found;
    }
}

sub remove_at_job {
	my ($jobid)=@_;
	Schedule::At::remove(JOBID => $jobid);
}

1;
__END__

=head1 BUGS

At some point C<C4::Scheduler> should be refactored:

=over

=item At and C<Schedule::At> does not work on Win32.

=item At is not installed by default on all platforms.

=item The At queue used by Koha is owned by the httpd user.  If multiple
Koha databases share an Apache instance on a server, everybody can
see everybody's jobs.

=item There is no support for scheduling a job to run more than once.

=back

=head1 AUTHOR

Chris Cormack <crc@liblime.com>

=cut
