node default {

  include stdlib

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
