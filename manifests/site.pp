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
