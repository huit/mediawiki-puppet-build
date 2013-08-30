node default {

  include stdlib

  # use APC for PHP opcode caching
  package { 'php-pecl-apc':
    ensure => 'present',
    before => Class['mediawiki'],
  }

  # PHP XML support for content import
  package { 'php-xml':
    ensure => 'present',
    before => Class['mediawiki'],
  }

  # needs to be modified to talk to RDS
  class { 'mediawiki':
    server_name      => $::ec2_public_hostname,
    admin_email      => 'admin@example.com',
    db_root_password => 'password',
    doc_root         => '/var/www/html',
    max_memory       => '1024',
  }

  mediawiki::instance { 'wiki':
    db_password => 'wikipassword',
    db_name     => 'wiki',
    db_user     => 'wiki_user',
    port        => '80',
    ensure      => 'present'
  }

  # install LocalS3Repos plugin


}
