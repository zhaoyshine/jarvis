require "jarvis/error"
require "shellwords"
require "bundler"
require "open4"

module Jarvis
  class SubprocessFailure < ::Jarvis::Error ; end
  JRUBY_VERSION = "9.1.14.0"

  def self.execute(args, logger, directory=nil)
    logger.info("Running command", :args => args)
    # We have to wrap the command into this block to make sure the current command use his 
    # defined set of gems and not jarvis gems.
    # Bundler.with_clean_env do
      pid, stdin, stdout, stderr = if directory
                                     cd_rvm_args = [
                                         "cd #{Shellwords.shellescape(directory)}",
                                         ". #{rvm_path}/scripts/rvm",
                                         "echo PWD; pwd",
                                         "rvm use #{JRUBY_VERSION}; rvm use; #{args}"
                                     ]
                                     wrapped = [ 'env', '-' ]
                                     wrapped.concat env_to_shell_lines(execute_env)
                                     wrapped.concat [ 'bash', '-c', cd_rvm_args.join('; ') ]
                                     Open4::popen4(*wrapped)
                                   else
                                     Open4::popen4(*args)
                                   end
      stdin.close
      logger.pipe(stdout => :info, stderr => :error)
      _, status = Process::waitpid2(pid)
      raise SubprocessFailure, "subprocess failed with code #{status.exitstatus}" unless status.success?
    # end
  end

  class << self

    private

    def rvm_path
      ENV['rvm_path'] || '~/.rvm'
    end

    def execute_env
      [ 'PATH', 'HOME', 'SSH_AUTH_SOCK' ].map do |var|
        ENV[var] ? [ var, ENV[var] ] : nil
      end.compact.to_h
    end

    def env_to_shell_lines(env)
      env.map { |var, val| "#{var}=#{Shellwords.shellescape(val)}" }
    end

  end
end
