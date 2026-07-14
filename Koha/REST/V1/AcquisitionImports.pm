package Koha::REST::V1::AcquisitionImports;

# Copyright 2026 LMSCloud GmbH
# License: GPL-3.0-or-later

=head1 NAME

Koha::REST::V1::AcquisitionImports - REST API Controller für Acquisition-Import-Tabellen

=head1 DESCRIPTION

Stellt Lesezugriff auf die Tabellen C<acquisition_import> und
C<acquisition_import_objects> über die Koha REST API bereit.

Endpunkte (nach Registrierung in swagger.json):

    GET /api/v1/acquisitionimports
    GET /api/v1/acquisitionimports/{id}
    GET /api/v1/acquisitionimports/objects
    GET /api/v1/acquisitionimports/objects/{id}

=cut

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';

use C4::Context;
use Scalar::Util qw(looks_like_number);

# ---------------------------------------------------------------------------
# Interne Hilfsmethoden
# ---------------------------------------------------------------------------

# Spalten einer Tabelle aus INFORMATION_SCHEMA ermitteln.
# Wird gecacht, damit SHOW COLUMNS nicht bei jedem Request neu läuft.
my %_col_cache;

sub _columns {
    my ( $self, $table ) = @_;
    return $_col_cache{$table} if exists $_col_cache{$table};

    my $dbh  = C4::Context->dbh;
    my $sth  = $dbh->prepare('SHOW COLUMNS FROM `' . $table . '`');
    $sth->execute;
    my @cols = map { $_->[0] } @{ $sth->fetchall_arrayref };
    $_col_cache{$table} = \@cols;
    return \@cols;
}

# Generische List-Implementierung für eine Tabelle.
# Unterstützt: Pagination (_page, _per_page), Volltextsuche (q),
# Sortierung (_order_by: +col / -col), optionale Zusatzfilter (key => value).
sub _list {
    my ( $self, $table, %opts_and_filter ) = @_;

    # Sonderoptionen herausziehen (kein Spaltenname, kein Filter)
    my $extra_select = delete $opts_and_filter{_extra_select} // '';
    my %extra_filter = %opts_and_filter;

    my $dbh      = C4::Context->dbh;
    my $page     = int( $self->param('_page')     // 1  );
    my $per_page = int( $self->param('_per_page') // 25 );
    my $q        = $self->param('q')        // '';
    my $order_by = $self->param('_order_by') // '+id';

    # Plausibilitätsgrenzen
    $page     = 1   if $page     < 1;
    $per_page = 1   if $per_page < 1;
    $per_page = 500 if $per_page > 500;

    my $offset  = ( $page - 1 ) * $per_page;
    my $columns = $self->_columns($table);

    unless ( @$columns ) {
        return $self->render(
            status  => 404,
            openapi => { error => "Tabelle '$table' nicht gefunden oder hat keine Spalten." }
        );
    }

    # WHERE aufbauen
    my ( @conditions, @params );

    # Volltextsuche
    if ( $q ne '' ) {
        push @conditions, '(' . join( ' OR ', map { "`$_` LIKE ?" } @$columns ) . ')';
        push @params, ( "%$q%" ) x scalar @$columns;
    }

    # Zusatzfilter
    for my $key ( sort keys %extra_filter ) {
        # Datumsbereich: _date_from_<spalte> → DATE(`spalte`) >= 'YYYY-MM-DD'
        if ( $key =~ /^_date_from_(.+)$/ ) {
            my $col = $1;
            my $val = $extra_filter{$key};
            next unless defined $val && $val =~ /^\d{4}-\d{2}-\d{2}$/;
            next unless grep { $_ eq $col } @$columns;
            push @conditions, "DATE(`$col`) >= ?";
            push @params, $val;
            next;
        }
        # Datumsbereich: _date_to_<spalte> → DATE(`spalte`) <= 'YYYY-MM-DD'
        if ( $key =~ /^_date_to_(.+)$/ ) {
            my $col = $1;
            my $val = $extra_filter{$key};
            next unless defined $val && $val =~ /^\d{4}-\d{2}-\d{2}$/;
            next unless grep { $_ eq $col } @$columns;
            push @conditions, "DATE(`$col`) <= ?";
            push @params, $val;
            next;
        }
        # Datumsfilter: _date_<spalte> → DATE(`spalte`) = 'YYYY-MM-DD'
        if ( $key =~ /^_date_(.+)$/ ) {
            my $col = $1;
            my $val = $extra_filter{$key};
            next unless defined $val && $val =~ /^\d{4}-\d{2}-\d{2}$/;
            next unless grep { $_ eq $col } @$columns;   # Injection-Schutz
            push @conditions, "DATE(`$col`) = ?";
            push @params, $val;
            next;
        }
        my $val = $extra_filter{$key};
        next unless defined $val && $val ne '';
        next unless grep { $_ eq $key } @$columns;   # Injection-Schutz
        if ( index($val, '%') >= 0 ) {
            push @conditions, "`$key` LIKE ?";
        } else {
            push @conditions, "`$key` = ?";
        }
        push @params, $val;
    }

    my $where = @conditions ? 'WHERE ' . join( ' AND ', @conditions ) : '';

    # Sortierung parsen
    my ( $ord_dir, $ord_col ) = ( 'ASC', $columns->[0] );
    if ( $order_by =~ /^([+-])(.+)$/ ) {
        $ord_dir = $1 eq '-' ? 'DESC' : 'ASC';
        $ord_col = $2;
    }
    # Spaltenname gegen bekannte Spalten prüfen
    $ord_col = $columns->[0] unless grep { $_ eq $ord_col } @$columns;

    # Zählabfragen
    my ($total) = $dbh->selectrow_array("SELECT COUNT(*) FROM `$table`");
    my ($filtered) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM `$table` $where", undef, @params
    );

    # Daten holen
    my $rows = $dbh->selectall_arrayref(
        "SELECT *$extra_select FROM `$table` $where ORDER BY `$ord_col` $ord_dir LIMIT ? OFFSET ?",
        { Slice => {} },
        @params, $per_page, $offset
    );

    return $self->render(
        status  => 200,
        openapi => {
            total    => $total    + 0,
            filtered => $filtered + 0,
            page     => $page,
            per_page => $per_page,
            columns  => $columns,
            data     => $rows,
        }
    );
}

# ---------------------------------------------------------------------------
# Endpunkte: acquisition_import
# ---------------------------------------------------------------------------

=head2 list

    GET /api/v1/acquisitionimports

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    my $columns = $c->_columns('acquisition_import');

    # _distinct-Modus: gibt eindeutige Werte einer Spalte zurück (für Dropdown-Filter)
    my $distinct_col = $c->param('_distinct');
    if ( $distinct_col ) {
        return $c->render( status => 400, openapi => { error => 'Ungültige Spalte' } )
            unless grep { $_ eq $distinct_col } @$columns;
        my $dbh  = C4::Context->dbh;
        my $vals = $dbh->selectcol_arrayref(
            "SELECT DISTINCT `$distinct_col` FROM acquisition_import"
            . " WHERE `$distinct_col` IS NOT NULL AND `$distinct_col` != ''"
            . " ORDER BY `$distinct_col`"
        );
        return $c->render( status => 200, openapi => { values => $vals || [] } );
    }

    my %filter;

    # Spaltenfilter: jeden Request-Param der einem Spaltennamen entspricht übernehmen
    for my $col ( @$columns ) {
        my $val = $c->param($col);
        $filter{$col} = $val if defined $val && $val ne '';
    }

    # Datumsbereich-Parameter weitergeben
    for my $col ( @$columns ) {
        for my $pfx ( '_date_from_', '_date_to_' ) {
            my $key = $pfx . $col;
            my $val = $c->param($key);
            $filter{$key} = $val if defined $val && $val ne '';
        }
    }

    # Correlated subquery: invoiceid für Rechnungszeilen (object_type = 'invoice')
    $filter{_extra_select} =
        q{, (SELECT invoiceid FROM aqinvoices}
      . q{ WHERE invoicenumber = object_number LIMIT 1) AS invoiceid};

    return $c->_list('acquisition_import', %filter);
}

=head2 get

    GET /api/v1/acquisitionimports/{id}

=cut

sub get {
    my $c   = shift->openapi->valid_input or return;
    my $id  = $c->param('id');
    my $dbh = C4::Context->dbh;

    my $row = $dbh->selectrow_hashref(
        'SELECT * FROM `acquisition_import` WHERE id = ?',
        undef, $id
    );

    return $row
        ? $c->render( status => 200, openapi => $row )
        : $c->render( status => 404, openapi => { error => 'Datensatz nicht gefunden' } );
}

# ---------------------------------------------------------------------------
# Endpunkte: acquisition_import_objects
# ---------------------------------------------------------------------------

=head2 list_objects

    GET /api/v1/acquisitionimports/objects

=cut

sub list_objects {
    my $c = shift->openapi->valid_input or return;

    my %filter;
    my $import_id = $c->param('import_id');
    $filter{acquisition_import_id} = $import_id if defined $import_id && $import_id ne '';

    return $c->_list( 'acquisition_import_objects', %filter );
}

=head2 get_object

    GET /api/v1/acquisitionimports/objects/{id}

=cut

sub get_object {
    my $c   = shift->openapi->valid_input or return;
    my $id  = $c->param('id');
    my $dbh = C4::Context->dbh;

    my $row = $dbh->selectrow_hashref(
        'SELECT * FROM `acquisition_import_objects` WHERE id = ?',
        undef, $id
    );

    return $row
        ? $c->render( status => 200, openapi => $row )
        : $c->render( status => 404, openapi => { error => 'Datensatz nicht gefunden' } );
}

# ---------------------------------------------------------------------------
# Endpunkt: JOIN-Ansicht (acquisition_import + objects + biblio + items)
# ---------------------------------------------------------------------------

=head2 list_joined

    GET /api/v1/acquisitionimports/joined

Liefert acquisition_import LEFT JOIN acquisition_import_objects LEFT JOIN biblio
LEFT JOIN biblio_metadata LEFT JOIN items – angereichert mit Titel, Autor,
Verlag, Jahr und Barcode aus den Koha-Tabellen.

Parameter:
  import_id  – filtert auf eine bestimmte acquisition_import.id
  _page, _per_page, q, _order_by – wie bei den anderen Endpunkten

=cut

sub list_joined {
    my $c = shift->openapi->valid_input or return;

    my $dbh      = C4::Context->dbh;
    my $page     = int( $c->param('_page')     // 1  );
    my $per_page = int( $c->param('_per_page') // 25 );
    my $q        = $c->param('q')        // '';
    my $order_by     = $c->param('_order_by')    // '+ai.id';
    my $object_number = $c->param('object_number');

    $page     = 1   if $page     < 1;
    $per_page = 1   if $per_page < 1;
    $per_page = 500 if $per_page > 500;
    my $offset = ( $page - 1 ) * $per_page;

    my %valid_order_cols = (
        id                  => 'ai.id',
        vendor_id           => 'ai.vendor_id',
        object_type         => 'ai.object_type',
        rec_type            => 'ai.rec_type',
        object_number       => 'ai.object_number',
        object_item_number  => 'ai.object_item_number',
        processingtime      => 'ai.processingtime',
        processingstate     => 'ai.processingstate',
        koha_object_id      => 'ao.koha_object_id',
        title               => 'b.title',
        datecreated         => 'b.datecreated',
        barcode             => 'i.barcode',
    );

    my $join_clause = q{
        FROM acquisition_import ai
        LEFT JOIN acquisition_import_objects ao
               ON ai.id = ao.acquisition_import_id
        LEFT JOIN biblio b
               ON ao.koha_object_id = b.biblionumber
        LEFT JOIN biblio_metadata AS meta
               ON ao.koha_object_id = meta.biblionumber
              AND ao.koha_object = 'title'
        LEFT JOIN items AS i
               ON ao.koha_object_id = i.itemnumber
              AND ao.koha_object = 'item'
        LEFT JOIN aqorders_items aqoi
               ON aqoi.itemnumber = i.itemnumber
        LEFT JOIN aqorders aqo
               ON aqo.ordernumber = aqoi.ordernumber
        LEFT JOIN aqinvoices inv
               ON inv.invoicenumber = ai.object_number
              AND ai.object_type = 'invoice'
    };

    # Kein object_number übergeben → leeres Ergebnis (noch keine Auswahl im Master)
    unless ( defined $object_number && $object_number ne '' ) {
        my @empty_cols = qw(id vendor_id object_type rec_type object_number object_item_number
                            processingtime processingstate koha_object_id
                            title author publisher year datecreated barcode item_timestamp);
        return $c->render(
            status  => 200,
            openapi => { total => 0, filtered => 0, page => 1, per_page => $per_page,
                         columns => \@empty_cols, data => [] }
        );
    }

    my ( @conditions, @params );

    push @conditions, 'ai.object_number = ?';
    push @params, $object_number;

    if ( $q ne '' ) {
        my @search_cols = qw(
            ai.vendor_id ai.object_type ai.rec_type
            ai.object_number ai.processingstate b.title i.barcode
        );
        push @conditions, '(' . join( ' OR ', map { "$_ LIKE ?" } @search_cols ) . ')';
        push @params, ( "%$q%" ) x scalar @search_cols;
    }

    my $where = @conditions ? 'WHERE ' . join( ' AND ', @conditions ) : '';

    my $ord_sql = 'ai.id ASC';
    if ( $order_by =~ /^([+-])(.+)$/ ) {
        my ( $dir, $col ) = ( $1 eq '-' ? 'DESC' : 'ASC', $2 );
        $ord_sql = $valid_order_cols{$col} . ' ' . $dir
            if exists $valid_order_cols{$col};
    }

    my ($total) = $dbh->selectrow_array(
        "SELECT COUNT(*) $join_clause WHERE ai.object_number = ?", undef, $object_number
    );
    my ($filtered) = $dbh->selectrow_array(
        "SELECT COUNT(*) $join_clause $where", undef, @params
    );

    my $rows = $dbh->selectall_arrayref( qq{
        SELECT
            ai.id,
            ai.vendor_id,
            ai.object_type,
            ai.rec_type,
            ai.object_number,
            ai.object_item_number,
            ai.processingtime,
            ai.processingstate,
            ao.koha_object_id,
            b.title,
            ExtractValue(meta.metadata,'//datafield[\@tag="245"]/subfield[\@code="c"]') AS author,
            ExtractValue(meta.metadata,'//datafield[\@tag="264"]/subfield[\@code="b"]') AS publisher,
            ExtractValue(meta.metadata,'//datafield[\@tag="264"]/subfield[\@code="c"]') AS year,
            b.datecreated,
            i.barcode,
            i.timestamp AS item_timestamp,
            i.biblionumber AS item_biblionumber,
            aqo.basketno AS basketno,
            inv.invoiceid AS invoiceid
        $join_clause
        $where
        ORDER BY $ord_sql
        LIMIT ? OFFSET ?
    }, { Slice => {} }, @params, $per_page, $offset );

    my @columns = qw(
        id vendor_id object_type rec_type object_number object_item_number
        processingtime processingstate koha_object_id
        title author publisher year datecreated barcode item_timestamp
    );

    return $c->render(
        status  => 200,
        openapi => {
            total    => $total    + 0,
            filtered => $filtered + 0,
            page     => $page,
            per_page => $per_page,
            columns  => \@columns,
            data     => $rows,
        }
    );
}

1;