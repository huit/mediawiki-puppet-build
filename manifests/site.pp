node default {

  include stdlib

  $nepho_instance_role = hiera('NEPHO_INSTANCE_ROLE')

  case $nepho_instance_role {
    'varnish': {
      # tier 1
      $nepho_external_hostname = hiera('NEPHO_EXTERNAL_HOSTNAME')

      # FIXME needs a custom VCL
      class { 'varnish': }
    }
    'mediawiki': {
      # tier 2
      $nepho_external_hostname = hiera('NEPHO_EXTERNAL_HOSTNAME')
      $nepho_backend_hostname = hiera('NEPHO_BACKEND_HOSTNAME')
      $nepho_database_host = hiera('NEPHO_DATABASE_HOST')
      $nepho_database_port = hiera('NEPHO_DATABASE_PORT')
      $nepho_database_name = hiera('NEPHO_DATABASE_NAME')
      $nepho_database_user = hiera('NEPHO_DATABASE_USER')
      $nepho_database_password = hiera('NEPHO_DATABASE_PASSWORD')

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
        server_name      => $nepho_external_hostname,
        admin_email      => 'admin@example.com',
        db_root_password => 'password',
        doc_root         => '/var/www/html',
        max_memory       => '1024',
      }

      mediawiki::instance { 'wiki':
        ensure      => 'present',
        db_password => $nepho_database_password,
        db_name     => $nepho_database_name,
        db_user     => $nepho_database_user,
        port        => '8080',
      }

      # install LocalS3Repos plugin
    }
    default: {
      # standalone
      class { 'varnish':
        before => Class['mediawiki'],
      }

      $nepho_external_hostname = hiera('NEPHO_EXTERNAL_HOSTNAME')
      $nepho_backend_hostname = hiera('NEPHO_BACKEND_HOSTNAME')
      $nepho_database_host = hiera('NEPHO_DATABASE_HOST')
      $nepho_database_port = hiera('NEPHO_DATABASE_PORT')
      $nepho_database_name = hiera('NEPHO_DATABASE_NAME')
      $nepho_database_user = hiera('NEPHO_DATABASE_USER')
      $nepho_database_password = hiera('NEPHO_DATABASE_PASSWORD')

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
        server_name      => $nepho_external_hostname,
        admin_email      => 'admin@example.com',
        db_root_password => 'password',
        doc_root         => '/var/www/html',
        max_memory       => '1024',
      }

      mediawiki::instance { 'wiki':
        ensure      => 'present',
        db_password => $nepho_database_password,
        db_name     => $nepho_database_name,
        db_user     => $nepho_database_user,
        port        => '8080',
      }

      # install LocalS3Repos plugin
    }
  }



}
