require 'omf/job_service/resource'
require 'omf-sfa/resource/oresource'
require 'time'
require 'fileutils'
require 'tmpdir'
require 'openssl'

module OMF::JobService::Resource

  # This class represents a user in the system.
  #
  class User < OMF::SFA::Resource::OResource
    DEF_LIFE_TIME = 86400 * 30 * 6

    oproperty :expiration, DataMapper::Property::Time
    oproperty :creation, DataMapper::Property::Time
    oproperty :email, String
    oproperty :jobs, :job, functional: false #, inverse: :user # not implmented yet

    DEF_CREDENTIALS_DIR = '/tmp/job_service/slices/credentials'

    #
    #     credendials_dir: '/tmp/job_service/slices'
    #
    def self.init(cfg)
      @@credendials_dir = cfg[:credendials_dir] || DEF_CREDENTIALS_DIR
      FileUtils.mkdir_p @@credendials_dir
    end

    # Return a user whose credentials are included in 'bundle'
    #
    #  bundle:
    #    content: (base64 encoded zip file containing geni_cert.pem)
    def self.from_bundle(bundle)
      Dir.mktmpdir do |dir|
        zip_file_name = "#{dir}/bundle.zip"
        zip_file = File.open(zip_file_name, "w")
        s = Zlib::Inflate.inflate(Base64.decode64(bundle[:content].join("\n")))
        zip_file.write(s)
        zip_file.close
        `cd #{dir}; unzip bundle.zip`

        File.open("#{dir}/geni_cert.pem", 'r') do |f|
          pem = f.read
          return from_pem(pem)
        end
      end
    end

    # Return a user whose credentials are included in 'bundle'
    #
    #  @param pem - Pem encoded credential
    #
    def self.from_pem(pem)
      cert = OpenSSL::X509::Certificate.new(pem)
      an = cert.extensions.find {|ex| ex.oid == 'subjectAltName'}
      unless an
        raise "Cert doesn't include a 'subjectAltName' extension"
      end
      line = an.value
      email = (line.match /.*email:([\w\.@]*)/)[1]
      name = email.split('@')[0]
      urn = (line.match /.*(URI:urn:publicid:IDN[\w\+\.]*)/)[1]
      uuid_m = line.match /.*URI:urn:uuid:([\h\-]*)/
      if uuid_m
        uuid = uuid_m[1]
      end

      user = self.first_or_create(uuid ? {uuid: uuid} : {urn: urn})
      user.email = email
      user.name = name
      user.save

      cfg_dir = user.omni_config_dir
      FileUtils.mkdir_p(cfg_dir)
      pf = File.open(File.join(cfg_dir, 'geni_cert.pem'), 'w')
      pf.write(pem)
      pf.close

      cf = File.open(File.join(cfg_dir, 'omni_config'), 'w')
      cfg = OMNI_CONFIG.gsub('%USER%', name).gsub('%URN%', urn).gsub('%CFG_DIR%', cfg_dir)
      #puts ">> #{cfg}"
      cf.write(cfg)
      cf.close

      user
    end


    def initialize(opts)
      super
      self.creation = Time.now
      self.expiration = Time.now + DEF_LIFE_TIME
    end

    def omni_config_dir
      File.join(@@credendials_dir, self.name)
    end

    def to_hash_long(h, objs = {}, opts = {})
      super
      #h[:certificate] = href() + '/cert'
      h
    end

    OMNI_CONFIG = %{
[omni]
default_cf = portal
users = %USER%
default_project = GIMITesting

[portal_chapi]
type = chapi
authority=ch.geni.net
ch=https://ch.geni.net:8444/CH
cert = %CFG_DIR%/geni_cert.pem
key = %CFG_DIR%/geni_cert.pem
# For debugging
verbose=false

[portal]
type = pgch
authority=ch.geni.net
ch = https://ch.geni.net/PGCH
sa = https://ch.geni.net/PGCH
cert = %CFG_DIR%/geni_cert.pem
key = %CFG_DIR%/geni_cert.pem

[%USER%]
urn = %URN%
    }

  end # classs
end # module
