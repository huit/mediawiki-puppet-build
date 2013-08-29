#!/bin/bash

echo 'Beginning run of bootstrap.sh'

logfile='/tmp/bootstrap.log'

# configure hiera
if [[ -f './manifests/bootstrap.pp' ]]; then
    puppet apply ./manifests/bootstrap.pp
    echo "Exit value: $?"
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

echo 'Completing run of bootstrap.sh'
