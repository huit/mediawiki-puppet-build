node default {

  include stdlib
                                                                                                                                                                     
#  class { 'mysql::server': }
#  class { 'mysql::php':    }
  
#  class { 'apache':}
#  class { 'apache::mod::ssl': }
#  class { 'apache::mod::php': }

#  apache::vhost { $fqdn:
#    vhost_name => $fqdn,
#    port => 80,
#    docroot => '/var/www/wordpress'
#  }

class { 'mediawiki':
  server_name        => 'www.myawesomesite.com',
  admin_email         => 'admin@example.com',
  db_root_password => 'password',
  doc_root         => '/var/www',
  max_memory       => '1024'
}
  
 mediawiki::instance { 'wiki':
   db_password => 'wikipassword',
   db_name     => 'wiki',
   db_user     => 'wiki_user',
   port        => '80',
   ensure      => 'present'
 }


}