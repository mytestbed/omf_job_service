
OMF Experiment Service
======================

This directory contains the implementations of an Experiment Service
which executes experiments on behalf of users.

Installation
------------

At this stage the best course of action is to clone the repository

    % git clone https://github.com/mytestbed/omf_exp_service.git
    % cd omf_job_service
    % bundle install --path vendor
    
Starting the Service
--------------------

To start a project authority with a some pre-populated resources ('--test-load-state') from this directory, run the following:

    % cd omf_job_service
    % bundle exec bin/omf_job_service --test-load-state --dm-auto-upgrade --disable-https start
    
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

    
