#!/usr/bin/env ruby
#
#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-16.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
#
#  All administrator configuration options are in config.rb.
#
require_relative '../config'
require 'gserver'
require_relative 'database'
require_relative 'connection'
require_relative 'object' # Thing, etc.
require_relative 'console'

module RubyMUCK
  RM_VERSION = '0.1a'

  class Server < GServer
    def initialize(port, host, maxConnections=-1)
      super(port, host, maxConnections)
      @audit = true
    end
    def serve(io)
      session = Connection.new(self, io)
      session.ioLoop
    end
    def error(detail, message='')
      log("ERROR: #{message}: #{detail}\n")
      log(detail.backtrace[0..5].join("\n"))
    end
    def log(message)
      super(message)
    end
    def stopping()
      super
      # Can't do this here because this method is called AFTER everybody has been disconnected.
      #Connection.putsAll "Server shutdown.\n"
    end
  
    def self.run
      # Run the server with logging enabled (it's a separate thread).
      $server = Server.new(PORT, HOST, MAX_CONNECTIONS)
      #server.audit = true                  # Turn logging on.
      $server.debug = ENABLE_DEBUGGING

      database.load

      Connection.load_modules # Do an initial module load.

      $server.start

      if ENABLE_CONSOLE
        Console.new.run
        $server.stop
      end

      $server.join
    end
    
    def save
      log "Saving to database..."
      meas = Benchmark.measure { 
        if DATABASE_MIRRORED
          database.save_mirror
        else
          database.save
        end
      }
      log "Saved in %0.3fs." % meas.real
    end
  end
end

if __FILE__ == $0
  RubyMUCK::Server.run
end
