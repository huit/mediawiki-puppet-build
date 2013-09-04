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
  $nepho_s3_bucket         = hiera('NEPHO_S3_BUCKET',false)
  $nepho_s3_access_key     = hiera('NEPHO_S3_BUCKET_ACCESS','no_s3_bucket_access_provided')
  $nepho_s3_secret_key     = hiera('NEPHO_S3_BUCKET_KEY','no_s3_bucket_secret_provided')

  $probe_interval     = "30s"
  $probe_timeout      = "10s"
  $probe_window       = "5"
  $purge_ips          = [  ]

  case $nepho_instance_role {
    'varnish': {
      # tier 1
      # use a custom VCL
      class { 'varnish':
        vcl_content => inline_template(file('/tmp/mediawiki-puppet-build/templates/tiered.vcl.erb'))
      }
    }
    'mediawiki': {
      # tier 2
      # FIXME needs additional nepho params for db root user and root password
      class { 'nepho_mediawiki':
        server_name      => $nepho_external_hostname,
        db_server        => $nepho_database_host,
        db_root_user     => $nepho_database_user,
        db_root_password => $nepho_database_password,
        db_name          => $nepho_database_name,
        db_user          => $nepho_database_user,
        db_password      => $nepho_database_password,
        db_port          => $nepho_database_port,
        app_port         => $default_application_port,
        s3_bucket        => $nepho_s3_bucket,
        s3_access_key    => $nepho_s3_access_key,
        s3_secret_key    => $nepho_s3_secret_key,
      }
    }
    default: {
      # standalone
      class { 'varnish': }
      class { 'nepho_mediawiki':
        server_name      => $nepho_external_hostname,
        db_server        => $nepho_database_host,
        db_root_user     => 'root',
        db_root_password => $nepho_database_password,
        db_name          => $nepho_database_name,
        db_user          => $nepho_database_user,
        db_password      => $nepho_database_password,
        db_port          => $nepho_database_port,
        app_port         => $default_application_port,
      }
    }
  }
}

class nepho_mediawiki (
  $server_name,
  $db_server,
  $db_root_user,
  $db_root_password,
  $db_name,
  $db_user,
  $db_password,
  $db_port,
  $app_port,
  $admin_email = 'admin@example.com',
  $doc_root = '/var/www/html',
  $max_memory = '1024',
  $s3_bucket = false,
  $s3_access_key = false,
  $s3_secret_key = false,
  $ensure = 'present'
) {
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
    server_name      => $nepho_mediawiki::server_name,
    admin_email      => $nepho_mediawiki::admin_email,
    db_server        => $nepho_mediawiki::db_server,
    db_root_user     => $nepho_mediawiki::db_root_user,
    db_root_password => $nepho_mediawiki::db_root_password,
    doc_root         => $nepho_mediawiki::doc_root,
    max_memory       => $nepho_mediawiki::max_memory,
  }

  mediawiki::instance { 'huitarch':
    ensure      => 'present',
    db_server   => $nepho_mediawiki::db_server,
    db_password => $nepho_mediawiki::db_password,
    db_name     => $nepho_mediawiki::db_name,
    db_user     => $nepho_mediawiki::db_user,
    port        => $nepho_mediawiki::app_port,
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
  file_line { 'additional_settings':
    path    => '/etc/mediawiki/huitarch/LocalSettings.php',
    line    => 'require("LocalSettings-nepho.php");',
    require => Mediawiki::Instance['huitarch'],
  }

  file { '/etc/mediawiki/huitarch/LocalSettings-nepho.php':
    content => inline_template(file('/tmp/mediawiki-puppet-build/templates/LocalSettings-nepho.php.erb')),
    owner => root,
    group => root,
    mode => 0644,
  }

  s3file { '/tmp/huitarch.xml':
    source => 'huitarch-2013-09-03-release/huitarch.xml'
  }
  s3file { '/tmp/images.tar':
    source => 'huitarch-2013-09-03-release/images.tar'
  }

  exec { 'nepho-huitarch-import':
    cwd     => '/etc/mediawiki/huitarch',
    path    => ['/bin', '/usr/bin'],
    command => 'tar xvf /tmp/images.tar -C /tmp; mkdir -p images/{archive,thumb,temp}; php maintenance/importDump.php --conf LocalSettings.php /tmp/huitarch.xml',
    creates => '/tmp/images',
    require => [
      S3file['/tmp/huitarch.xml'],
      S3file['/tmp/images.tar'],
      Mediawiki::Instance['huitarch'],
    ],
    notify => Exec['nepho-huitarch-rebuild'],
  }

  exec { 'nepho-huitarch-rebuild':
    cwd     => '/etc/mediawiki/huitarch',
    path    => ['/bin', '/usr/bin'],
    command => 'php maintenance/rebuildRecentChanges.php --conf LocalSettings.php; php maintenance/update.php --conf LocalSettings.php; php maintenance/importImages.php --conf LocalSettings.php /tmp/images pdf jpg',
    notify => Exec['nepho-huitarch-import-images'],
    refreshonly => true,
  }

  exec { 'nepho-huitarch-import-images':
    cwd     => '/etc/mediawiki/huitarch',
    path    => ['/bin', '/usr/bin'],
    command => 'php maintenance/importImages.php --conf LocalSettings.php /tmp/images pdf jpg',
    notify => Exec['nepho-huitarch-import-images'],
    refreshonly => true,
  }

  if $nepho_mediawiki::s3_bucket != false {
    # Copy images to s3
    exec { 'nepho-huitarch-populate-s3':
      cwd     => '/etc/mediawiki/huitarch',
      path    => ['/bin', '/usr/bin'],
      command => "s3put -a '$nepho_mediawiki::s3_access_key' -s '$nepho_mediawiki::s3_secret_key' -b $s3_bucket -d 1 -g public-read images",
    }
  }
}
