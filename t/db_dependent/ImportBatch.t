#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 16;
use utf8;
use File::Basename;
use File::Temp qw/tempfile/;

use t::lib::Mocks;
use t::lib::TestBuilder;

use Koha::Database;
use Koha::Plugins;

BEGIN {
    # Mock pluginsdir before loading Plugins module
    my $path = dirname(__FILE__) . '/../lib';
    t::lib::Mocks::mock_config( 'pluginsdir', $path );
    use_ok('C4::ImportBatch');
}

# Start transaction
my $schema  = Koha::Database->new->schema;
$schema->storage->txn_begin;
my $builder = t::lib::TestBuilder->new;
my $dbh = C4::Context->dbh;

# clear
$dbh->do('DELETE FROM import_batches');

my $sample_import_batch1 = {
    matcher_id => 1,
    template_id => 1,
    branchcode => 'QRT',
    overlay_action => 'create_new',
    nomatch_action => 'create_new',
    item_action => 'always_add',
    import_status => 'staged',
    batch_type => 'z3950',
    file_name => 'test.mrc',
    comments => 'test',
    record_type => 'auth',
};

my $sample_import_batch2 = {
    matcher_id => 2,
    template_id => 2,
    branchcode => 'QRZ',
    overlay_action => 'create_new',
    nomatch_action => 'create_new',
    item_action => 'always_add',
    import_status => 'staged',
    batch_type => 'z3950',
    file_name => 'test.mrc',
    comments => 'test',
    record_type => 'auth',
};

my $id_import_batch1 = C4::ImportBatch::AddImportBatch($sample_import_batch1);
my $id_import_batch2 = C4::ImportBatch::AddImportBatch($sample_import_batch2);

like( $id_import_batch1, '/^\d+$/', "AddImportBatch for sample_import_batch1 return an id" );
like( $id_import_batch2, '/^\d+$/', "AddImportBatch for sample_import_batch2 return an id" );

#Test GetImportBatch
my $importbatch2 = C4::ImportBatch::GetImportBatch( $id_import_batch2 );
delete $importbatch2->{upload_timestamp};
delete $importbatch2->{import_batch_id};
delete $importbatch2->{num_records};
delete $importbatch2->{num_items};
delete $importbatch2->{profile_id};
delete $importbatch2->{profile};

is_deeply( $importbatch2, $sample_import_batch2,
    "GetImportBatch returns the right informations about $sample_import_batch2" );

my $importbatch1 = C4::ImportBatch::GetImportBatch( $id_import_batch1 );
delete $importbatch1->{upload_timestamp};
delete $importbatch1->{import_batch_id};
delete $importbatch1->{num_records};
delete $importbatch1->{num_items};
delete $importbatch1->{profile_id};
delete $importbatch1->{profile};

is_deeply( $importbatch1, $sample_import_batch1,
    "GetImportBatch returns the right informations about $sample_import_batch1" );

my $record = MARC::Record->new;
# FIXME Create another MARC::Record which won't be modified
# AddItemsToImportBiblio will remove the items field from the record passed in parameter.
my $original_record = MARC::Record->new;
$record->leader('03174nam a2200445 a 4500');
$original_record->leader('03174nam a2200445 a 4500');
my ($item_tag, $item_subfield) = C4::Biblio::GetMarcFromKohaField( 'items.itemnumber' );
my @fields = (
    MARC::Field->new(
        100, '1', ' ',
        a => 'Knuth, Donald Ervin',
        d => '1938',
    ),
    MARC::Field->new(
        245, '1', '4',
        a => 'The art of computer programming',
        c => 'Donald E. Knuth.',
    ),
    MARC::Field->new(
        650, ' ', '0',
        a => 'Computer programming.',
        9 => '462',
    ),
    MARC::Field->new(
        $item_tag, ' ', ' ',
        e => 'my edition ❤',
        i => 'my item part',
    ),
    MARC::Field->new(
        $item_tag, ' ', ' ',
        e => 'my edition 2',
        i => 'my item part 2',
    ),
);
$record->append_fields(@fields);
$original_record->append_fields(@fields);
my $import_record_id = AddBiblioToBatch( $id_import_batch1, 0, $record, 'utf8', int(rand(99999)), 0 );
AddItemsToImportBiblio( $id_import_batch1, $import_record_id, $record, 0 );

my $record_from_import_biblio_with_items = C4::ImportBatch::GetRecordFromImportBiblio( $import_record_id, 'embed_items' );
$original_record->leader($record_from_import_biblio_with_items->leader());
is_deeply( $record_from_import_biblio_with_items, $original_record, 'GetRecordFromImportBiblio should return the record with items if specified' );
my $utf8_field = $record_from_import_biblio_with_items->subfield($item_tag, 'e');
is($utf8_field, 'my edition ❤');
$original_record->delete_fields($original_record->field($item_tag)); #Remove items fields
my $record_from_import_biblio_without_items = C4::ImportBatch::GetRecordFromImportBiblio( $import_record_id );
$original_record->leader($record_from_import_biblio_without_items->leader());
is_deeply( $record_from_import_biblio_without_items, $original_record, 'GetRecordFromImportBiblio should return the record without items by default' );

my $another_biblio = $builder->build_sample_biblio;
C4::ImportBatch::SetMatchedBiblionumber( $import_record_id, $another_biblio->biblionumber );
my $import_biblios = GetImportBiblios( $import_record_id );
is( $import_biblios->[0]->{matched_biblionumber}, $another_biblio->biblionumber, 'SetMatchedBiblionumber  should set the correct biblionumber' );

# Add a few tests for GetItemNumbersFromImportBatch
my @a = GetItemNumbersFromImportBatch( $id_import_batch1 );
is( @a, 0, 'No item numbers expected since we did not commit' );
my $itemno = $builder->build_sample_item->itemnumber;
# Link this item to the import item to fool GetItemNumbersFromImportBatch
my $sql = "UPDATE import_items SET itemnumber=? WHERE import_record_id=?";
$dbh->do( $sql, undef, $itemno, $import_record_id );
@a = GetItemNumbersFromImportBatch( $id_import_batch1 );
is( @a, 2, 'Expecting two items now' );
is( $a[0], $itemno, 'Check the first returned itemnumber' );
# Now delete the item and check again
$dbh->do( "DELETE FROM items WHERE itemnumber=?", undef, $itemno );
@a = GetItemNumbersFromImportBatch( $id_import_batch1 );
is( @a, 0, 'No item numbers expected since we deleted the item' );
$dbh->do( $sql, undef, undef, $import_record_id ); # remove link again

# fresh data
my $sample_import_batch3 = {
    matcher_id => 3,
    template_id => 3,
    branchcode => 'QRT',
    overlay_action => 'create_new',
    nomatch_action => 'create_new',
    item_action => 'always_add',
    import_status => 'staged',
    batch_type => 'z3950',
    file_name => 'test.mrc',
    comments => 'test',
    record_type => 'auth',
};

my $id_import_batch3 = C4::ImportBatch::AddImportBatch($sample_import_batch3);

# Test CleanBatch
C4::ImportBatch::CleanBatch( $id_import_batch3 );
my $import_record = get_import_record( $id_import_batch3 );
is( $import_record, "0E0", "Batch 3 has been cleaned" );

# Test DeleteBatch
C4::ImportBatch::DeleteBatch( $id_import_batch3 );
my $import_batch = C4::ImportBatch::GetImportBatch( $id_import_batch3 );
is( $import_batch, undef, "Batch 3 has been deleted");

subtest "RecordsFromMarcPlugin" => sub {
    plan tests => 5;

    # Create a test file
    my ( $fh, $name ) = tempfile();
    print $fh q|
003 = NLAmRIJ
100,a = Author
245,ind2 = 0
245,a = Silence in the library
500 , a= Some note

100,a = Another
245,a = Noise in the library|;
    close $fh;

    t::lib::Mocks::mock_config( 'enable_plugins', 1 );

    my $plugins = Koha::Plugins->new;
    $plugins->InstallPlugins;
    my ($plugin) = $plugins->GetPlugins({ all => 1, metadata => { name => 'MarcFieldValues' } });
    isnt( $plugin, undef, "Plugin found" );
    my $records = C4::ImportBatch::RecordsFromMarcPlugin( $name, ref $plugin, 'UTF-8' );
    is( @$records, 2, 'Two results returned' );
    is( ref $records->[0], 'MARC::Record', 'Returned MARC::Record object' );
    is( $records->[0]->subfield('245', 'a'), 'Silence in the library',
        'Checked one field in first record' );
    is( $records->[1]->subfield('100', 'a'), 'Another',
        'Checked one field in second record' );
};

sub get_import_record {
    my $id_import_batch = shift;
    return $dbh->do('SELECT * FROM import_records WHERE import_batch_id = ?', undef, $id_import_batch);
}

$schema->storage->txn_rollback;
