package Koha::BackgroundJob::BatchDeleteAuthority;

use Modern::Perl;

use C4::AuthoritiesMarc;

use Koha::DateUtils qw( dt_from_string );
use Koha::SearchEngine;
use Koha::SearchEngine::Indexer;

use base 'Koha::BackgroundJob';

sub job_type {
    return 'batch_authority_record_deletion';
}

sub process {
    my ( $self, $args ) = @_;

    if ( $self->status eq 'cancelled' ) {
        return;
    }

    # FIXME If the job has already been started, but started again (worker has been restart for instance)
    # Then we will start from scratch and so double delete the same records

    my $job_progress = 0;
    $self->started_on(dt_from_string)
        ->progress($job_progress)
        ->status('started')
        ->store;

    my $mmtid = $args->{mmtid};
    my @record_ids = @{ $args->{record_ids} };

    my $report = {
        total_records => scalar @record_ids,
        total_success => 0,
    };
    my @messages;
    my $schema = Koha::Database->new->schema;
    RECORD_IDS: for my $record_id ( sort { $a <=> $b } @record_ids ) {

        last if $self->get_from_storage->status eq 'cancelled';

        next unless $record_id;

        $schema->storage->txn_begin;

        my $authid = $record_id;
        eval {
            C4::AuthoritiesMarc::DelAuthority(
                { authid => $authid, skip_record_index => 1 } );
        };
        if ( $@ ) {
            push @messages, {
                type => 'error',
                code => 'authority_not_deleted',
                authid => $authid,
                error => "$@",
            };
            $schema->storage->txn_rollback;
            next;
        } else {
            push @messages, {
                type => 'success',
                code => 'authority_deleted',
                authid => $authid,
            };
            $report->{total_success}++;
            $schema->storage->txn_commit;
        }

        $self->progress( ++$job_progress )->store;
    }

    my @deleted_authids =
      map { $_->{code} eq 'authority_deleted' ? $_->{authid} : () }
          @messages;

    if ( @deleted_authids ) {
        my $indexer = Koha::SearchEngine::Indexer->new({ index => $Koha::SearchEngine::AUTHORITIES_INDEX });
        $indexer->index_records( \@deleted_authids, "recordDelete", "authorityserver" );
    }

    my $json = $self->json;
    my $job_data = $json->decode($self->data);
    $job_data->{messages} = \@messages;
    $job_data->{report} = $report;

    $self->ended_on(dt_from_string)
        ->data($json->encode($job_data));
    $self->status('finished') if $self->status ne 'cancelled';
    $self->store;
}

sub enqueue {
    my ( $self, $args) = @_;

    # TODO Raise exception instead
    return unless exists $args->{record_ids};

    my @record_ids = @{ $args->{record_ids} };

    $self->SUPER::enqueue({
        job_size  => scalar @record_ids,
        job_args  => {record_ids => \@record_ids,},
        job_queue => 'long_tasks',
    });
}

1;
