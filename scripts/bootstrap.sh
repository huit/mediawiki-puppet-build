#!/bin/bash

echo 'Beginning run of bootstrap.sh'

logfile='/tmp/bootstrap.log'

# configure hiera
if [[ -f './manifests/bootstrap.pp' ]]; then
    puppet apply ./manifests/bootstrap.pp
else
    echo "Hiera deployment manifest not available."
fi

# populate hiera
if [[ -x './scripts/env2yaml.rb' ]]; then
    ./scripts/env2yaml.rb > /etc/puppet/hieradata/common.yaml
    echo "Exit value: $?"
else
    echo "Hiera population script not available."
fi

# fix the hostname (wtf?)
if [[ -x '/bin/hostname' && -x '/usr/bin/facter' && -x '/usr/bin/puppet' ]]; then
    /bin/hostname $(/usr/bin/facter -p ec2_hostname) && \
        /usr/bin/puppet resource host $(facter -p ec2_hostname) ensure=present ip=$(facter -p ec2_local_ipv4)
else
    echo "Unable to set hostname."
fi

echo 'Completing run of bootstrap.sh'
