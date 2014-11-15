#!/usr/bin/env perl
use strict;
use warnings;

use Google::BigQuery;

use Data::Dumper;

my $client_email = $ENV{CLIENT_EMAIL};
my $private_key_file = $ENV{PRIVATE_KEY_FILE};
my $project_id = $ENV{PROJECT_ID};

my $bq = Google::BigQuery::create(
  client_email => $client_email,
  private_key_file => $private_key_file,
  project_id => $project_id
);

my @datasets = grep /^sample_dataset_/, $bq->show_datasets;

foreach my $dataset (@datasets) {
  my @tables = $bq->show_tables(dataset_id => $dataset);
  foreach my $table (@tables) {
    $bq->drop_table(dataset_id => $dataset, table_id => $table);
  }

  print "drop dataset: $dataset\n";
  $bq->drop_dataset(dataset_id => $dataset);
}
