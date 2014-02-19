
THIS_DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
$: << File.absolute_path(File.join(THIS_DIR, '..', '..'))

require 'json'
require 'omf/job_service/server'

opts = OMF::JobService::DEF_OPTS
OMF::JobService::Server.new.run(opts)
