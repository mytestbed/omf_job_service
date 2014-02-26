
This directory will contain a working OMF EC configured

Installation
------------

Before starting, make sure the following libraries are installed. On Debian systems, the following should suffice:

    apt-get install libpq-dev
    apt-get install libxml2-dev
    apt-get install libxslt

The install the GEMS and local modifications

    bundle install --path vendor
    export FRCP_URL=amqp://localhost # or your favorite FRCP comms provider
    rake post-install

Testing
-------

To test the setup, run a simple experiment

    ./omf_ec simple_test.oedl -- --res1 test1

which should show you something like:

    OMF Experiment Controller - Copyright (c) 2012-13 National ICT Australia Limited (NICTA)
    04:01:48 INFO  Object: OMF Experiment Controller 6.0.8.pre.4
    04:01:48 INFO  Object: Connected using {:proto=>:amqp, :user=>"guest", :domain=>"127.0.0.1"}
    04:01:48 INFO  Object: Execute: /home/ubuntu/omf_job_service/omf_ec/simple_test.oedl
    04:01:48 INFO  Object: Properties: {}
    04:01:48 INFO  OmfEc::ExperimentProperty: res1 = "test1" (String)
    04:01:48 INFO  OmfEc::Experiment: Experiment: 2014-02-05T04:01:47.926Z starts
    04:01:48 INFO  OmfEc::Experiment: Configure 'test1' to join 'Actor'

If you want to test it with a fully local setup, checkout the [README](../test/omf_rc/README.md)
in the '../test/omf_rc' directory for standing up a local RC

To test if the OML environment is setup correctly as well, use

    export OML_SERVER=tcp:srv.mytestbed.net:3004
    ./omf_ec --oml_uri $OML_SERVER simple_oml_test.oedl
