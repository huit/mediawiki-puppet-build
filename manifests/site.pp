node default {
  include stdlib

  # parameter defaults
  $default_database_host     = 'localhost'
  $default_database_port     = '3306'
  $default_database_name     = 'mediawiki'
  $default_database_user     = 'mediawiki'
  $default_database_password = 'mediawiki'
  $default_application_port  = '8080'

  # parameters passed from nepho
  $nepho_instance_role     = hiera('NEPHO_INSTANCE_ROLE')
  $nepho_external_hostname = hiera('NEPHO_EXTERNAL_HOSTNAME',$::ec2_public_hostname)
  $nepho_backend_hostname  = hiera('NEPHO_BACKEND_HOSTNAME','localhost')
  $nepho_database_host     = hiera('NEPHO_DATABASE_HOST',$default_database_host)
  $nepho_database_port     = hiera('NEPHO_DATABASE_PORT',$default_database_port)
  $nepho_database_name     = hiera('NEPHO_DATABASE_NAME',$default_database_name)
  $nepho_database_user     = hiera('NEPHO_DATABASE_USER',$default_database_user)
  $nepho_database_password = hiera('NEPHO_DATABASE_PASSWORD',$default_database_password)


  case $nepho_instance_role {
    'varnish': {
      # tier 1
      # use a custom VCL
      class { 'varnish':
        vcl_content => inline_template(file('templates/tiered.vcl.erb'))
      }
    }
    'mediawiki': {
      # tier 2
      class { 'nepho_mediawiki': }
    }
    default: {
      # standalone
      class { 'varnish': }
      class { 'nepho_mediawiki': }
    }
  }
}

class nepho_mediawiki {
  $mw_pkgs = [
    'php-pecl-apc', # Use APC for PHP opcode caching
    'php-xml',      # PHP XML support for content import
    'php-intl',     # PHP Unicode normalization
  ]

  package { $mw_pkgs:
    ensure => present,
    before => Class['mediawiki'],
  }

  # needs to be modified to talk to RDS
  class { 'mediawiki':
    server_name      => $::nepho_external_hostname,
    admin_email      => 'admin@example.com',
    db_server        => $::nepho_database_host,
    db_root_user     => $::nepho_database_user,
    db_root_password => $::nepho_database_password,
    doc_root         => '/var/www/html',
    max_memory       => '1024',
  }

  mediawiki::instance { 'huitarch':
    ensure      => 'present',
    db_password => $::nepho_database_password,
    db_name     => $::nepho_database_name,
    db_user     => $::nepho_database_user,
    port        => $::default_application_port,
  }

  include s3file::curl
  S3file { require => Mediawiki::Instance['huitarch'] }

  s3file { '/etc/mediawiki/huitarch/extensions/LocalS3Repo.zip':
    source => 'huitarch-2013-09-03-release/LocalS3Repo.zip',
    notify => Exec['unzip-locals3repo'],
  }
  s3file { '/etc/mediawiki/huitarch/extensions/gists.php':
    source => 'huitarch-2013-09-03-release/gists.php'
  }

  exec { 'unzip-locals3repo':
    cwd         => '/etc/mediawiki/huitarch/extensions',
    command     => '/usr/bin/unzip LocalS3Repo.zip',
    refreshonly => true,
  }

  # modify localsettings.php

  # If the huitarch wiki is empty, run setup on one node
  #if $::nepho_first_run == 'true' {
    s3file { '/tmp/huitarch.xml':
      source => 'huitarch-2013-09-03-release/huitarch.xml'
    }
    s3file { '/tmp/images.tar':
      source => 'huitarch-2013-09-03-release/images.tar'
    }

    # TODO: how to make sure this command only runs once?
    exec { 'setup-huitarch':
      cwd     => '/etc/mediawiki/huitarch',
      path    => ['/bin', '/usr/bin'],
      command => 'tar xvf /tmp/images.tar -C /tmp; mkdir -p images/{archive,thumb,temp}; php maintenance/importDump.php --conf LocalSettings.php /tmp/huitarch.xml; php maintenance/rebuildRecentChanges.php --conf LocalSettings.php; php maintenance/update.php --conf LocalSettings.php; php maintenance/importImages.php --conf LocalSettings.php /tmp/images pdf jpg',
      require => [
        S3file['/tmp/huitarch.xml'],
        S3file['/tmp/images.tar'],
        Mediawiki::Instance['huitarch'],
      ],
    }
  #}
}
