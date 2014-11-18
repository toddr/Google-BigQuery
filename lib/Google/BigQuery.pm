package Google::BigQuery;
use 5.010001;
use strict;
use warnings;

our $VERSION = "0.03";

use Class::Load qw(load_class);
use Crypt::OpenSSL::PKCS12;
use JSON qw(decode_json encode_json);
use JSON::WebToken;
use LWP::UserAgent;

sub create {
  my (%args) = @_;

  my $version = $args{version} // 'v2';
  my $class = 'Google::BigQuery::' . ucfirst($version);

  if (load_class($class)) {
    return $class->new(%args);
  } else {
    die "Can't load class: $class";
  }
}

sub new {
  my ($class, %args) = @_;

  die "undefined client_eamil" if !defined $args{client_email};
  die "undefined private_key_file" if !defined $args{private_key_file};
  die "not found private_key_file" if !-f $args{private_key_file};

  my $self = bless { %args }, $class;

  $self->{GOOGLE_API_TOKEN_URI} = 'https://accounts.google.com/o/oauth2/token';
  $self->{GOOGLE_API_GRANT_TYPE} = 'urn:ietf:params:oauth:grant-type:jwt-bearer';

  if ($self->{private_key_file} =~ /\.json$/) {
    open my $in, "<", $self->{private_key_file} or die "can't open $self->{private_key_file} : $!";
    my $private_key_json = decode_json(join('', <$in>));
    close $in;
    $self->{private_key} = $private_key_json->{private_key};
  } elsif ($self->{private_key_file} =~ /\.p12$/) {
    my $password = "notasecret";
    my $pkcs12 = Crypt::OpenSSL::PKCS12->new_from_file($self->{private_key_file});
    $self->{private_key} = $pkcs12->private_key($password);
  } else {
    die "invalid private_key_file format";
  }

  $self->_auth;
  $self->_set_rest_description;

  return $self;
}

sub DESTROY {
}

sub _auth {
  my ($self) = @_;

  $self->{scope} //= 'https://www.googleapis.com/auth/bigquery';
  $self->{exp} = time + 3600;
  $self->{iat} = time;
  $self->{ua} = LWP::UserAgent->new;

  my $claim = {
    iss => $self->{client_email},
    scope => ($self->{scope}),
    aud => $self->{GOOGLE_API_TOKEN_URI},
    exp => $self->{exp},
    iat => $self->{iat},
  };

  my $jwt = JSON::WebToken::encode_jwt($claim, $self->{private_key}, 'RS256', { type => 'JWT' });

  my $response = $self->{ua}->post(
    $self->{GOOGLE_API_TOKEN_URI},
    { grant_type => $self->{GOOGLE_API_GRANT_TYPE}, assertion => $jwt }
  );

  if ($response->is_success) {
    $self->{access_token} = decode_json($response->decoded_content);
  } else {
    my $error = decode_json($response->decoded_content);
    die $error->{error};
  }
}

sub _set_rest_description {
  my ($self) = @_;
  my $response = $self->{ua}->get($self->{GOOGLE_BIGQUERY_REST_DESCRIPTION});
  $self->{rest_description} = decode_json($response->decoded_content);
}

sub use_project {
  my ($self, $project_id) = @_;
  $self->{project_id} = $project_id // return;
}

sub use_dataset {
  my ($self, $dataset_id) = @_;
  $self->{dataset_id} = $dataset_id // return;
}

sub create_dataset {
  my ($self, %args) = @_;

  my $project_id = $args{project_id} // $self->{project_id};
  my $dataset_id = $args{dataset_id} // $self->{dataset_id};

  unless ($project_id) {
    warn "no project\n";
    return 0;
  }
  unless ($dataset_id) {
    warn "no dataset\n";
    return 0;
  }

  my $response = $self->request(
    resource => 'datasets',
    method => 'insert',
    project_id => $project_id,
    dataset_id => $dataset_id,
    content => {
      datasetReference => {
        projectId => $project_id,
        datasetId => $dataset_id
      }
    }
  );

  if (defined $response->{error}) {
    warn $response->{error}{message};
    return 0;
  } else {
    return 1;
  }
}

sub drop_dataset {
  my ($self, %args) = @_;

  my $project_id = $args{project_id} // $self->{project_id};
  my $dataset_id = $args{dataset_id};

  unless ($project_id) {
    warn "no project\n";
    return 0;
  }
  unless ($dataset_id) {
    warn "no dataset\n";
    return 0;
  }

  my $response = $self->request(
    resource => 'datasets',
    method => 'delete',
    project_id => $project_id,
    dataset_id => $dataset_id
  );

  if (defined $response->{error}) {
    warn $response->{error}{message};
    return 0;
  } else {
    return 1;
  }
}

sub show_datasets {
  my ($self, %args) = @_;

  my $project_id = $args{project_id} // $self->{project_id};

  unless ($project_id) {
    warn "no project\n";
    return undef;
  }

  my $response = $self->request(
    resource => 'datasets',
    method => 'list',
    project_id => $project_id
  );

  if (defined $response->{error}) {
    warn $response->{error}{message};
    return undef;
  }

  my @ret = ();
  foreach my $dataset (@{$response->{datasets}}) {
    push @ret, $dataset->{datasetReference}{datasetId};
  }

  return @ret;
}

sub create_table {
  my ($self, %args) = @_;

  my $project_id = $args{project_id} // $self->{project_id};
  my $dataset_id = $args{dataset_id} // $self->{dataset_id};
  my $table_id = $args{table_id};
  my $schema = $args{schema};

  unless ($project_id) {
    warn "no project\n";
    return 0;
  }
  unless ($dataset_id) {
    warn "no dataset\n";
    return 0;
  }
  unless ($table_id) {
    warn "no table\n";
    return 0;
  }

  my $response = $self->request(
    resource => 'tables',
    method => 'insert',
    project_id => $project_id,
    dataset_id => $dataset_id,
    table_id => $table_id,
    content => {
      tableReference => {
        projectId => $project_id,
        datasetId => $dataset_id,
        tableId => $table_id
      },
      schema => {
        fields => $schema
      }
    }
  );

  if (defined $response->{error}) {
    warn $response->{error}{message};
    return 0;
  } elsif (defined $schema && !defined $response->{schema}) {
    warn "no create schema";
    return 0;
  } else {
    return 1;
  }
}

sub drop_table {
  my ($self, %args) = @_;

  my $project_id = $args{project_id} // $self->{project_id};
  my $dataset_id = $args{dataset_id} // $self->{dataset_id};
  my $table_id = $args{table_id};

  unless ($project_id) {
    warn "no project\n";
    return 0;
  }
  unless ($dataset_id) {
    warn "no dataset\n";
    return 0;
  }
  unless ($table_id) {
    warn "no table\n";
    return 0;
  }

  my $response = $self->request(
    resource => 'tables',
    method => 'delete',
    project_id => $project_id,
    dataset_id => $dataset_id,
    table_id => $table_id
  );

  if (defined $response->{error}) {
    warn $response->{error}{message};
    return 0;
  } else {
    return 1;
  }
}

sub show_tables {
  my ($self, %args) = @_;

  my $project_id = $args{project_id} // $self->{project_id};
  my $dataset_id = $args{dataset_id} // $self->{dataset_id};

  unless ($project_id) {
    warn "no project\n";
    return undef;
  }
  unless ($dataset_id) {
    warn "no dataset\n";
    return undef;
  }

  my $response = $self->request(
    resource => 'tables',
    method => 'list',
    project_id => $project_id,
    dataset_id => $dataset_id
  );

  if (defined $response->{error}) {
    warn $response->{error}{message};
    return undef;
  }

  my @ret = ();
  foreach my $table (@{$response->{tables}}) {
    push @ret, $table->{tableReference}{tableId};
  }

  return @ret;
}

sub load {
  my ($self, %args) = @_;

  my $project_id = $args{project_id} // $self->{project_id};
  my $dataset_id = $args{dataset_id} // $self->{dataset_id};
  my $table_id = $args{table_id};
  my $data = $args{data};

  unless ($project_id) {
    warn "no project\n";
    return 0;
  }
  unless ($dataset_id) {
    warn "no dataset\n";
    return 0;
  }
  unless ($table_id) {
    warn "no table\n";
    return 0;
  }
  unless ($data) {
    warn "no data\n";
    return 0;
  }

  my $content = {
    configuration => {
      load => {
        destinationTable => {
          projectId => $project_id,
          datasetId => $dataset_id,
          tableId => $table_id,
        }
      }
    }
  };

  if ($data =~ /\.(tsv|csv|json)(?:\.gz)?$/i) {
    my $suffix = $1;

    my $source_format;
    my $field_delimiter;
    if ($suffix =~ /^tsv$/i) {
      $field_delimiter = "\t";
    } elsif ($suffix =~ /^json$/i) {
      $source_format = "NEWLINE_DELIMITED_JSON";
    }

    $content->{configuration}{load}{sourceFormat} = $source_format if defined $source_format;
    $content->{configuration}{load}{fieldDelimiter} = $field_delimiter if defined $field_delimiter;
  } else {
    warn "invalid suffix";
    return 0;
  }

  # load options
  $content->{configuration}{load}{schema}{fields} = $args{schema} if defined $args{schema};

  my $response = $self->request(
    resource => 'jobs',
    method => 'insert',
    project_id => $project_id,
    dataset_id => $dataset_id,
    talbe_id => $table_id,
    content => $content,
    data => $data
  );

  if (defined $response->{error}) {
    warn $response->{error}{message};
    return 0;
  } elsif ($response->{status}{state} eq 'DONE') {
    if (defined $response->{status}{errors}) {
      foreach my $error (@{$response->{status}{errors}}) {
        warn encode_json($error), "\n";
      }
      return 0;
    } else {
      return 1;
    }
  } else {
    return 0;
  }
}

sub insert {
  my ($self, %args) = @_;

  my $project_id = $args{project_id} // $self->{project_id};
  my $dataset_id = $args{dataset_id} // $self->{dataset_id};
  my $table_id = $args{table_id};
  my $values = $args{values};

  unless ($project_id) {
    warn "no project\n";
    return 0;
  }
  unless ($dataset_id) {
    warn "no dataset\n";
    return 0;
  }
  unless ($table_id) {
    warn "no table\n";
    return 0;
  }
  unless ($values) {
    warn "no values\n";
    return 0;
  }

  my $rows = [];
  foreach my $value (@$values) {
    push @$rows, { json => $value };
  }

  my $response = $self->request(
    resource => 'tabledata',
    method => 'insertAll',
    project_id => $project_id,
    dataset_id => $dataset_id,
    table_id => $table_id,
    content => {
      rows => $rows
    }
  );

  if (defined $response->{error}) {
    warn $response->{error}{message};
    return 0;
  } elsif (defined $response->{insertErrors}) {
    foreach my $error (@{$response->{insertErrors}}) {
      warn encode_json($error), "\n";
    }
    return 0;
  } else {
    return 1;
  }
}

sub selectrow_array {
  my ($self, %args) = @_;

  my $query = $args{query};
  my $project_id = $args{project_id} // $self->{project_id};
  my $dataset_id = $args{dataset_id} // $self->{dataset_id};

  unless ($query) {
    warn "no query\n";
    return 0;
  }
  unless ($project_id) {
    warn "no project\n";
    return 0;
  }

  my $content = {
    query => $query,
  };

  if (defined $dataset_id) {
    $content->{defaultDataset}{projectId} = $project_id;
    $content->{defaultDataset}{datasetId} = $dataset_id;
  }

  my $response = $self->request(
    resource => 'jobs',
    method => 'query',
    content => $content
  );

  if (defined $response->{error}) {
    warn $response->{error}{message};
    return 0;
  }

  my @ret = ();
  foreach my $field (@{$response->{rows}[0]{f}}) {
    push @ret, $field->{v};
  }

  return @ret;
}

sub selectall_arrayref {
  my ($self, %args) = @_;

  my $query = $args{query};
  my $project_id = $args{project_id} // $self->{project_id};
  my $dataset_id = $args{dataset_id} // $self->{dataset_id};

  unless ($query) {
    warn "no query\n";
    return 0;
  }
  unless ($project_id) {
    warn "no project\n";
    return 0;
  }

  my $content = {
    query => $query,
  };

  if (defined $dataset_id) {
    $content->{defaultDataset}{projectId} = $project_id;
    $content->{defaultDataset}{datasetId} = $dataset_id;
  }

  my $response = $self->request(
    resource => 'jobs',
    method => 'query',
    content => $content
  );

  if (defined $response->{error}) {
    warn $response->{error}{message};
    return 0;
  }

  my $ret = [];
  foreach my $rows (@{$response->{rows}}) {
    my $row = [];
    foreach my $field (@{$rows->{f}}) {
      push @$row, $field->{v};
    }
    push @$ret, $row;
  }

  return $ret;
}

sub is_exists_dataset {
  my ($self, %args) = @_;

  my $project_id = $args{project_id} // $self->{project_id};
  my $dataset_id = $args{dataset_id} // $self->{dataset_id};

  unless ($project_id) {
    warn "no project\n";
    return 0;
  }
  unless ($dataset_id) {
    warn "no dataset\n";
    return 0;
  }

  my $response = $self->request(
    resource => 'datasets',
    method => 'get',
    project_id => $project_id,
    dataset_id => $dataset_id
  );

  if (defined $response->{error}) {
    #warn $response->{error}{message};
    return 0;
  } else {
    return 1;
  }
}

sub is_exists_table {
  my ($self, %args) = @_;

  my $project_id = $args{project_id} // $self->{project_id};
  my $dataset_id = $args{dataset_id} // $self->{dataset_id};
  my $table_id = $args{table_id};

  unless ($project_id) {
    warn "no project\n";
    return 0;
  }
  unless ($dataset_id) {
    warn "no dataset\n";
    return 0;
  }
  unless ($table_id) {
    warn "no table\n";
    return 0;
  }

  my $response = $self->request(
    resource => 'tables',
    method => 'get',
    project_id => $project_id,
    dataset_id => $dataset_id,
    table_id => $table_id
  );

  if (defined $response->{error}) {
    #warn $response->{error}{message};
    return 0;
  } else {
    return 1;
  }
}

1;
__END__

=encoding utf-8

=head1 NAME

Google::BigQuery - Google BigQuery Client Library for Perl

=head1 SYNOPSIS

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

=head1 DESCRIPTION

Google::BigQuery - Google BigQuery Client Library for Perl

=head1 TROUBLESHOOTING

=head2 Configure failed for Crypt-OpenSSL-PKCS12

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

=head1 LICENSE

Copyright (C) Shoji Kai.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Shoji Kai E<lt>sho2kai@gmail.comE<gt>

=cut

