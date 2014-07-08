
This directory will contain a working OMF EC configured

# Installation

Before starting, make sure the following libraries and ruby header files are installed. On Debian systems, the following should suffice:

    apt-get install ruby1.9.1-dev
    apt-get install libpq-dev
    apt-get install libxml2-dev
    apt-get install libxslt-dev

You will also need 'bundler' and 'rake', which can be installed with:

    gem install bundler
    gem install rake

The install the GEMS and local modifications

    bundle install --path vendor
    export FRCP_URL=amqp://localhost # or your favorite FRCP comms provider
    rake post-install

# IMPORTANT
-----------

Do not forget to set the FRCP URL variable as mentioned above with your *own* value for a comms provider, e.g. amqp://foo.com.

When using a local co-located AMQP server, please use the full hostname or address rather than 'localhost' as there seemed to be issues with the latter in the past.

# Upgrade EC

Locate Gemfile and find out reference to omf\_ec and omf\_common

For example:

    gem 'omf_common', override_with_local(path: '../../omf6/omf_common', version: "~> 6.1.2.pre")
    gem 'omf_ec', override_with_local(path: '../../omf6/omf_ec', version: "~> 6.1.2.pre")

To upgrade, simply change the content of key :version

Gem version convention is as following:

* ~> indicates matching minor releases, so it will automatically pick those bug fixes etc.
* ~> 6.1.2 will match all 6.1.x releases, until 6.2.0
* ~> 6.1.2.pre will match all 6.1.2 pre releases, i.e. 6.1.2.pre.x

Then simply do:

    bundle update

Check the output to see if desired version got installed.


# Testing

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
    ./omf_ec --oml_uri $OML_SERVER simple_oml_test.oedl -- --res1 test1

Note: the above simple oml example [simple_oml_test.oedl](./simple_oml_test.oedl)
assumes that there exists a resource identified as `test1`, which has an
application called `generator.rb` installed.
