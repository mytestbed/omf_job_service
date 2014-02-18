
OMF Job Service
===============

This directory contains the implementations of a Job Scheduling Service
which will first allocate resources to a job (experiment) and then
execute the job when the necessary resources become available.

Installation
------------

At this stage the best course of action is to clone the repository

    git clone https://github.com/mytestbed/omf_job_service.git
    cd omf_job_service

This service requires 'ruby1.9.3' provided by RVM. If you don't have one in this account, install it with:

    curl -sSL https://get.rvm.io | bash -s stable --ruby=1.9.3

Before installing the necessary Gems, make sure that you have the necessary libraries installed. On a Ubuntu
system, execute the following:

    sudo apt-get install sqlite3
    sudo apt-get install libxml2-dev
    sudo apt-get install libxslt-dev

On Ubuntu 12.04 LTS you will also need to install the following package:

    sudo apt-get install libsqlite3-dev

** At this stage, please clone https://github.com/mytestbed/omf_sfa.git into the parent directory and update it (git pull) regularily. **

Now we are ready to install all the necessary Gems

    bundle install --path vendor

Before starting the service, please also install tan OMF EC in the 'omf_ec' directoy
following the instructions in the [README](omf_ec/README.md) in that directory.

Starting the Service
--------------------

To start a job service from this directory, run the following:

    cd omf_job_service
    bin/omf_job_service --dm-auto-upgrade --disable-https start

which should result in something like:

    INFO Server: >> Thin web server (v1.3.1 codename Triple Espresso)
    DEBUG Server: >> Debugging ON
    DEBUG Server: >> Tracing ON
    INFO Server: >> Maximum connections set to 1024
    INFO Server: >> Listening on 0.0.0.0:8002, CTRL+C to stop


Testing REST API
----------------

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


