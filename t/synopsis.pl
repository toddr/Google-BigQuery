#!/usr/bin/env perl
use strict;
use warnings;

use Google::BigQuery;

my $client_email = $ENV{CLIENT_EMAIL};
my $private_key_file = $ENV{PRIVATE_KEY_FILE};
my $project_id = $ENV{PROJECT_ID};

# create a instance
my $bq = Google::BigQuery::create(
  client_email => $client_email,
  private_key_file => $private_key_file,
  project_id => $project_id,
);

# create a dataset
my $dataset_id = "sample_dataset_" . time;
$bq->create_dataset(
  dataset_id => $dataset_id
);
$bq->use_dataset($dataset_id);

# create a table
my $table_id = 'sample_table_' . time;
$bq->create_table(
  table_id => $table_id,
  schema => [
    { name => "id", type => "INTEGER", mode => "REQUIRED" },
    { name => "name", type => "STRING", mode => "NULLABLE" }
  ]
);

# load
my $load_file = "load_file.tsv";
open my $out, ">", $load_file or die;
for (my $id = 1; $id <= 100; $id++) {
  if ($id % 10 == 0) {
    print $out join("\t", $id, undef), "\n";
  } else {
    print $out join("\t", $id, "name-${id}"), "\n";
  }
}
close $out;

$bq->load(
  table_id => $table_id,
  data => $load_file,
);

unlink $load_file;

# selectrow_array
my ($count) = $bq->selectrow_array(query => "SELECT COUNT(*) FROM $table_id");
print $count, "\n";

# selectall_arrayref
my $aref = $bq->selectall_arrayref(query => "SELECT * FROM $table_id ORDER BY id");
foreach my $ref (@$aref) {
  print join("\t", @$ref), "\n";
}

# drop table
$bq->drop_table(table_id => $table_id);

# drop dataset
$bq->drop_dataset(dataset_id => $dataset_id);
