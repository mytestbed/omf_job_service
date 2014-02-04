
This directory will contain a working OMF EC configured

Installation
------------

    bundle install --path vendor
    
Testing
-------

To test the setup, run a simple experiment

    ./omf_ec simple_test.oedl
    
To test if the OML environment is setup correctly as well, use

    export OML_URL=tcp://srv.mytestbed.net:3004
    ./omf_ec --oml_uri $OML_URL simple_oml_test.oedl
  