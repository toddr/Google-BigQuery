#!/usr/bin/env perl
use strict;
use warnings;

use Google::BigQuery;

my $client_email = $ENV{CLIENT_EMAIL};
my $private_key_file = $ENV{PRIVATE_KEY_FILE};
my $project_id = $ENV{PROJECT_ID};
my $dataset_id = 'sample_dataset_' . time;

my $bigquery = Google::BigQuery::create(
  client_email => $client_email,            # required
  private_key_file => $private_key_file,    # required
  project_id => $project_id,                # optional (used as default project)
  dataset_id => $dataset_id,                # optional (used as default dataset)
);

# set default project
$bigquery->use_project($project_id);

# set default dataset
$bigquery->use_dataset($dataset_id);

# create dataset
$bigquery->create_dataset(
  dataset_id => $dataset_id,    # required if default dataset is not set
  project_id => $project_id     # required if default project is not set
);

# create table
my $table_id = 'sample_table_' . time;

$bigquery->create_table(
  table_id => $table_id,        # required
  dataset_id => $dataset_id,    # required if default dataset is not set
  project_id => $project_id,    # required if default project is not set
  schema => [                   # required
    { name => "id", type => "INTEGER", mode => "REQUIRED" },
    { name => "name", type => "STRING", mode => "NULLABLE" }
  ]
);

# insert
$bigquery->insert(
  table_id => $table_id,        # required
  dataset_id => $dataset_id,    # required if default dataset is not set
  project_id => $project_id,    # required if default project is not set
  values => [                   # required
    { id => 101, name => 'name101' },
    { id => 102 },
    { id => 103, name => 'name103' }
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

$bigquery->load(
  table_id => $table_id,        # required
  dataset_id => $dataset_id,    # required if default dataset is not set
  project_id => $project_id,    # required if default project is not set
  data => $load_file,           # required (suppored suffixes are tsv, csv, json and (tsv|csv|json).gz)
  schema => [                   # optional
    { name => "id", type => "INTEGER", mode => "REQUIRED" },
    { name => "name", type => "STRING", mode => "NULLABLE" }
  ]
);

unlink $load_file;

# selectrow_array
my ($count) = $bigquery->selectrow_array(query => "SELECT COUNT(*) FROM $table_id");
print $count, "\n";

# selectall_arrayref
my $aref = $bigquery->selectall_arrayref(query => "SELECT * FROM $table_id ORDER BY id");
foreach my $ref (@$aref) {
  print join("\t", @$ref), "\n";
}

# drop table
$bigquery->drop_table(table_id => $table_id);

# drop dataset
$bigquery->drop_dataset(dataset_id => $dataset_id);
