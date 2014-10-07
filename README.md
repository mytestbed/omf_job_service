
# OMF Job Service

This directory contains the implementations of a Job Scheduling Service
which will first allocate resources to a job (experiment) and then
execute the job when the necessary resources become available.

## Installation

At this stage the best course of action is to clone the repository

    git clone https://github.com/mytestbed/omf_job_service.git
    cd omf_job_service

This service requires Ruby version 1.9+. If you don't have one, install it according to https://www.ruby-lang.org/en/installation/

Before installing the necessary Gems, make sure that you have the necessary libraries installed. On a Ubuntu
system, execute the following:

    sudo apt-get install ruby1.9.1-dev sqlite3 libpq-dev

    # Only if you are going to use XMPP
    # sudo apt-get install libxml2-dev libxslt-dev

On Ubuntu 12.04 LTS you will also need to install the following package:

    sudo apt-get install libsqlite3-dev

Now we are ready to install all the necessary Gems

    bundle install --path vendor
    rake post-install

If you are installing on a Ubuntu 14.04 without RVM, you may need the following settings (which will be used during the installation of some dependencies)

    bundle config build.eventmachine --with-cflags=-O2 -pipe -march=native -w
    bundle config build.thin --with-cflags=-O2 -pipe -march=native -w

## Install OMF EC

*Before starting the service, please also install tan OMF EC in the 'omf_ec' directoy
following the instructions in the [README](omf_ec/README.md) in that directory.*

## IMPORTANT!!!

If you want to use an OML server with a PostgreSQL backend to log the resources of your experiment,
then you *MUST* update the config file etc/omf_job_service-local.yaml with the following:

    oml_server: 'tcp:your.oml.server.com.:3003'
    db_server: 'postgres://the_psql_user_to_use:the_password_for_that_user@your.psql.server.com'

Furthermore, if you are using this Job Service in conjunction of a LabWiki's Experiment Plugin, then
you *MUST* make sure that your PSQL server machine (e.g. your.psql.server.com in the above example)
have the following enabled:

* the TCP port 5432 is open, i.e. this allow clients to reach your PSQL server
* your PSQL server is configured to allow connection from remote clients (http://www.postgresql.org/docs/9.3/static/auth-pg-hba-conf.html), as an example this could be achieved by having the following line in your file pg_hba.conf. Please update according to your own security policy.

    host   all   all   0/0   md5


## Starting the Service

To start a job service from this directory, run the following:

    cd omf_job_service
    rake run

which should result in something like:

    DEBUG Server: Options: {:dm_log=>"/tmp/job_service_test-dm.log", :dm_db=>"sqlite:///tmp/job_service_test.db", ....
    DEBUG SimpleScheduler: Available resource: ["test1"]
    INFO Server: >> Thin web server (v1.3.1 codename Triple Espresso)
    DEBUG Server: >> Debugging ON
    DEBUG Server: >> Tracing ON
    INFO Server: >> Maximum connections set to 1024
    INFO Server: >> Listening on 0.0.0.0:8002, CTRL+C to stop


## Testing REST API

If you started the service with the '--test-load-state' option, the service got preloaded with a few
resources. To list all jobs:

    $ curl http://localhost:8002/jobs
    [
      {
        "uuid": "f9e25a8f-e2c0-5ccc-ba63-88469e6caf34",
        "href": "http://localhost:8002/jobs/f9e25a8f-e2c0-5ccc-ba63-88469e6caf34",
        "name": "job1",
        "type": "job",
        "status": "pending"
      },
      {
        "uuid": "c732bce9-8813-5e41-929e-173f74a56da0",
        "href": "http://localhost:8002/jobs/c732bce9-8813-5e41-929e-173f74a56da0",
        "name": "job2",
        "type": "job",
        "status": "pending"
      }
    ]

Or point a web browser at [http://localhost:8002/jobs?_format=html](http://localhost:8002/jobs?_format=html)

To schedule a new job:

    $ curl -X POST -H "Content-Type: application/json" --data-binary @test/job_request1.json http://localhost:8002/jobs
    {
      "type": "job",
      "uuid": "242dc8a0-0d0d-4914-b907-2bcc2093f366",
      "href": "http://localhost:8002/jobs/242dc8a0-0d0d-4914-b907-2bcc2093f366",
      "name": "foo-2000",
      "status": "pending"
    }

If you use the above web browser option, refresh the job listing and you should see a new link to job 'foo-2000'

A more user friendly way to schedule a job is using the 'post_job' command in the 'bin' directory

    $ bin/post_job -u http://localhost:8002/jobs omf_ec/simple_test.oedl -- --res1 @node
    Response 200 OK:
    {
      "type": "job",
      "uuid": "7dc784d6-e36d-4a0f-ba8f-a3d4b62eb55b",
      "href": "http://localhost:8002/jobs/7dc784d6-e36d-4a0f-ba8f-a3d4b62eb55b",
      "name": "exp_max_2014-02-05T13:56:16+11:00",
      "status": "pending"
    }

The list of parameters for the job itself can be listed after a '--' following the experiment script, similar to the 'omf_ec exec'
command. What is different here is the identification of a resource in the argument parameter. Resources are identified by a
'name@type' convention. If 'name' is omitted, the scheduler automatically assigns a suitable resource of the requested type.

To get a listing of the active, or pending jobs, got to [http://localhost:8002/queue](http://localhost:8002/queue?_format=html)


