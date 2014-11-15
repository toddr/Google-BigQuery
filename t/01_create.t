use strict;
use Test::More 0.98;
use FindBin '$Bin';
use JSON qw(decode_json);

use Google::BigQuery;

my $bigquery = Google::BigQuery::create(
  client_email => $ENV{CLIENT_EMAIL},
  private_key_file => $ENV{PRIVATE_KEY_FILE}
);
isnt($bigquery, undef, 'constructor');
isnt($bigquery->{access_token}, undef, 'access_token');

done_testing;

