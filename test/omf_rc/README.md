
Contains a complete RC environment to provide a few RCs for testing.

Installation
------------

    bundle install --path vendor
    export FRCP_URL=amqp://localhost # or your favorite FRCP comms provider
    rake post-install

Starting an RC
--------------

    ./start_rc -c test1_config.yaml
