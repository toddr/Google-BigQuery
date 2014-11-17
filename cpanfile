requires 'perl', '5.010001';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Class::Load';
    requires 'Crypt::OpenSSL::PKCS12';
    requires 'Crypt::OpenSSL::RSA';
    requires 'JSON';
    requires 'JSON::WebToken';
    requires 'LWP::UserAgent';
    requires 'HTTP::Request';
    requires 'URI::Escape';
    requires 'LWP::Protocol::https';
};

