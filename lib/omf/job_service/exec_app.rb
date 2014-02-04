# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'omf/job_service'
require 'fcntl'
require 'omf_base/lobject'

module OMF::JobService
  #
  # Run an application on the client.
  #
  # Borrows from Open3
  #
  class ExecApp < OMF::Base::LObject

    def self.start(id, cmd, env = nil, dir, &observer)
      if env
        cmd = "env -i #{env.map {|k,v| "#{k}=#{v}"}.join(' ')} #{cmd}"
      end
      self.new(id, cmd, false, dir, &observer)
    end

    # Holds the pids for all active apps
    @@all_apps = Hash.new

    # Return an application instance based on its ID
    #
    # @param [String] id of the application to return
    def self.[](id)
      app = @@all_apps[id]
      info "Unknown application '#{id}/#{id.class}'" if app.nil?
      return app
    end

    def self.signal_all(signal = 'KILL')
      @@all_apps.each_value { |app| app.signal(signal) }
    end

    attr_reader :pid, :clean_exit

    # True if this active app is being killed by a proper
    # call to ExecApp.signal_all() or signal()
    # (i.e. when the caller of ExecApp decided to stop the application,
    # as far as we are concerned, this is a 'clean' exit)
    @clean_exit = false

    def stdin(line)
      debug "Writing '#{line}' to app '#{@id}'"
      @stdin.write("#{line}\n")
      @stdin.flush
    end

    def signal(signal = 'KILL')
      debug "Sending signal '#{signal}' to app '#{@id}' with pid #{@pid}"
      @clean_exit = true
      Process.kill(signal, -1 * @pid) # we are sending to the entire process group
    end

    #
    # Run an application 'cmd' in a separate thread and monitor
    # its stdout. Also send status reports to the 'observer' by
    # calling its "call(eventType, appId, message")"
    #
    # @param id ID of application (used for reporting)
    # @param observer Observer of application's progress
    # @param cmd Command path and args
    # @param map_std_err_to_out If true report stderr as stdin [false]
    #
    def initialize(id, cmd, map_std_err_to_out = false, working_directory = nil, &observer)

      @id = id || self.object_id
      @observer = observer
      @@all_apps[@id] = self
      @exit_status = nil
      @threads = []

      pw = IO::pipe   # pipe[0] for read, pipe[1] for write
      pr = IO::pipe
      pe = IO::pipe

      debug "Starting application '#{@id}' - cmd: '#{cmd}'"
      #@observer.call(:STARTED, id, cmd)
      call_observer(:STARTED, cmd)
      @pid = fork {
        # child will remap pipes to std and exec cmd
        pw[1].close
        STDIN.reopen(pw[0])
        pw[0].close

        pr[0].close
        STDOUT.reopen(pr[1])
        pr[1].close

        pe[0].close
        STDERR.reopen(pe[1])
        pe[1].close

        begin
          pgid = Process.setsid # Create a new process group
                                # which includes all potential child processes
          STDOUT.puts "INTERNAL WARNING: Assuming process_group_id == pid" unless pgid == $$
          Dir.chdir working_directory if working_directory
          exec(cmd)
        rescue => ex
          cmd = cmd.join(' ') if cmd.kind_of?(Array)
          STDERR.puts "exec failed for '#{cmd}' (#{$!}): #{ex}"
        end
        # Should never get here
        exit!
      }

      pw[0].close
      pr[1].close
      pe[1].close
      monitor_pipe(:stdout, pr[0])
      monitor_pipe(map_std_err_to_out ? :stdout : :stderr, pe[0])
      # Create thread which waits for application to exit
      @threads << Thread.new(id, @pid) do |id, pid|
        Process.waitpid(pid)
        # Exit status is sometimes nil (OSX 10.8, ping)
        @exit_status = $?.exitstatus || 0
        if @exit_status > 127
          @exit_status = 128 - @exit_status
        end
        @@all_apps.delete(@id)
        # app finished
        if (@exit_status == 0) || @clean_exit
          debug "Application '#{@id}' finished"
        else
          debug "Application '#{@id}' failed (code=#{@exit_status})"
        end
      end
      @stdin = pw[1]

      # wait for done in yet another thread
      Thread.new do
        @threads.each {|t| t.join }
        call_observer("EXIT", @exit_status)
      end
      debug "Application is running with PID #{@pid}"
    end

    private

    #
    # Create a thread to monitor the process and its output
    # and report that back to the server
    #
    # @param name Name of app stream to monitor (should be :stdout, :stderr)
    # @param pipe Pipe to read from
    #
    def monitor_pipe(name, pipe)
      @threads << Thread.new() do
        begin
          while true do
            s = pipe.readline.chomp
            call_observer(name.to_s.upcase, s)
          end
        rescue EOFError
          # do nothing
        rescue  => err
          error "monitorApp(#{@id}): #{err}"
          debug "#{err}\n\t#{err.backtrace.join("\n\t")}"
        ensure
          pipe.close
        end
      end
    end

    def call_observer(event_type, msg)
      return unless @observer
      begin
        @observer.call(event_type, @id, msg)
      rescue Exception => ex
        warn "Exception while calling observer '#{@observer}': #{ex}"
        debug "#{ex}\n\t#{ex.backtrace.join("\n\t")}"
      end
    end

  end # class
end # module

if $0 == __FILE__
  OMF::Base::Loggable.init_log 'test'

  cmd = './omf_ec simple_test.oedl'

  RUBY = "ruby-1.9.3-p362"
  GEMSET = "global"
  PATH = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

  env = {
    HOME: (HOME = ENV['HOME']),
    RUBY: RUBY,
    GEMSET: GEMSET
    # PATH: "#{HOME}/.rvm/gems/#{RUBY}:#{HOME}/.rvm/gems/#{RUBY}@#{GEMSET}/bin:#{HOME}/.rvm/rubies/#{RUBY}/bin:#{HOME}/.rvm/bin:#{PATH}",
    # GEM_HOME: "#{HOME}/.rvm/gems/#{RUBY}",
    # GEM_PATH: "#{HOME}/.rvm/gems/#{RUBY}:#{HOME}/.rvm/gems/#{RUBY}@#{GEMSET}"
  }
  dir = File.join(File.dirname(__FILE__), '../../../omf_ec')
  OMF::JobService::ExecApp.start('test', cmd, env, dir) do |evtType, id, msg|
    puts "%#{evtType}: #{msg}"
  end

  sleep 50
end
