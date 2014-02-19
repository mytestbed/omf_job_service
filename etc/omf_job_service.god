
DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
BIN_DIR = File.absolute_path(File.join(DIR, '..', 'bin'))

God.watch do |w|
  w.name = "job_service"
  w.start = "#{BIN_DIR}/omf_job_service --dm-auto-upgrade --disable-https start"
  w.log = '/tmp/omf_job_service.log'
  w.keepalive
end
