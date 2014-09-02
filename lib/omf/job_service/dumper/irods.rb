require 'omf/job_service/dumper'
require 'omf/job_service/dumper/default'

module OMF::JobService
  class Dumper
    class IRODS < Default
      def initialize
        super
        # TODO Construct IRODS loc
        @irods_location = "irods_loc"
        @irods_user = opts[:irods_user]
        @irods_path = "https://www.irods.org/web/browse.php#ruri=#{@irods_user}.geniRenci@geni-gimi.renci.org:1247/geniRenci/home/gimiadmin/#{@irods_location}"
      end

      def dump
        `#{dump_cmd}`
        `imkdir #{@irods_location}`
        `iput #{@location} #{@irods_location}`

        path_html = "<a href='#{@irods_path}' target='_blank'>#{@irods_path}</a>"
        $?.exitstatus == 0 ? { success: path_html } : { error: 'Database dump to IRODS failed' }
      end
    end
  end
end
