# NAME

Google::BigQuery - Google BigQuery Client Library for Perl

# SYNOPSIS

    use Google::BigQuery;

    my $client_email = <YOUR CLIENT EMAIL ADDRESS>;
    my $private_key_file = <YOUR PRIVATE KEY FILE>;
    my $project_id = <YOUR PROJECT ID>;
    my $dataset_id = <YOUR DATASET ID>;

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
    my $table_id = 'sample_table';

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

# DESCRIPTION

Google::BigQuery - Google BigQuery Client Library for Perl

# TROUBLESHOOTING

## Configure failed for Crypt-OpenSSL-PKCS12

If such a following error occurrs,

    --> Working on Crypt::OpenSSL::PKCS12
    Fetching http://www.cpan.org/authors/id/D/DA/DANIEL/Crypt-OpenSSL-PKCS12-0.7.tar.gz ... OK
    Configuring Crypt-OpenSSL-PKCS12-0.6 ... N/A
    ! Configure failed for Crypt-OpenSSL-PKCS12-0.6. See /home/vagrant/.cpanm/work/1416208473.2527/build.log for details.

For now, you can work around it as below.

    cd /home/vagrant/.cpanm/work/1416208473.2527/Crypt-OpenSSL-PKCS12-0.7

    ### If you are a Mac user, you might also need the following steps.
    #
    # 1. Install new OpenSSL library and header.
    # brew install openssl
    #
    # 2. Add a lib_path and a includ_path to the Makefile.PL.
    # --- Makefile.PL.orig    2013-12-01 07:41:25.000000000 +0900
    # +++ Makefile.PL 2014-11-18 11:58:39.000000000 +0900
    # @@ -17,8 +17,8 @@
    #
    #  requires_external_cc();
    #
    # -cc_inc_paths('/usr/include/openssl', '/usr/local/include/ssl', '/usr/local/ssl/include');
    # -cc_lib_paths('/usr/lib', '/usr/local/lib', '/usr/local/ssl/lib');
    # +cc_inc_paths('/usr/local/opt/openssl/include', '/usr/include/openssl', '/usr/local/include/ssl', '/usr/local/ssl/include');
    # +cc_lib_paths('/usr/local/opt/openssl/lib', '/usr/lib', '/usr/local/lib', '/usr/local/ssl/lib');
    
    rm -fr inc
    cpanm Module::Install
    perl Makefile.PL
    make
    make test
    make install

# LICENSE

Copyright (C) Shoji Kai.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Shoji Kai <sho2kai@gmail.com>
