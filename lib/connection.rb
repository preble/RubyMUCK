#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-16.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
#
require 'monitor'
require_relative 'object'
require_relative 'taskmgr'
require_relative 'interpreted'

module RubyMUCK
  class Connection
    @@connections = {}
    @@connections.extend(MonitorMixin)
    @@commands = {}
    @@commands_ex = {}
    @@cmd_last_desc = nil
    @@cmd_last_help = nil
    @@cmd_last_allow = nil
  
    def initialize(server, io, player=nil)
      @server = server
      @io = io
      @player = player
      @parser = Parser.create(player, nil)
    end
    def ioLoop
      @@connections.synchronize {
        @@connections[Thread.current] = self
      }
    
      puts "== Welcome to #{MUCK_NAME}! =="
      # TODO: Banner?
      while @player.nil?
        puts "connect <name> <password>  to connect; QUIT disconnects."
        line = @io.gets
        # line will be nil if the user has disconnected.
        if line.nil? or line.strip! == 'QUIT' 
          return
        else
          begin
            m = line.match(/^connect\s+(\S*)\s+(.*)$/)
            unless m
              puts "Unknown command."
              next
            else
              name = m[1]
              password = m[2]
              @player = Player.login(name, password)
              if @player.nil?
                $server.log("Failed login for #{m[1]}")
                puts "Username or password incorrect."
                next
              # elsif @player.online?
              #   puts "#{@player.name} is already logged in!"
              #   @player = nil
              #   next
              else
                # Successfully logged in!
                $server.log("Logged in: #{@player}")
                @player.add_io @io
                break
              end
            end
          rescue => detail
            puts "An error has occurred: #{detail}"
            @server.log "Internal error on input: '#{line}'"
            @server.error detail
          end
        end
      end
    
      @player.look
    
      while @player
        line = @io.gets
        # line will be nil if the user has disconnected.
        if line.nil? or line.chomp! == 'QUIT' 
          break
        elsif line.empty?
          next
        else
          begin
            @player.last_activity = Time.now
            processInput(line)
          rescue => detail
            if detail.is_a? UserError
              puts detail
            else
              puts "An error has occurred: #{detail}"
              @server.log "Internal error on input: '#{line}'"
              @server.error detail
            end
          end
        end
      end
      puts "Goodbye.\n"
      @@connections.synchronize {
        @@connections.delete Thread.current
      }
      $server.log("Disconnected: #{@player}") unless @player.nil?
      @player.remove_io @io
    end
    def processInput(line)
      if m = line.match(/^"(.*?)"?$/)
        player_command('say', m[1])
      elsif m = line.match(/^:\s*(.*)$/)
        player_command('pose', m[1])
      else
        m = line.match /^\s*(\S+)\s*(.*)?\s*$/
        raise "Error matching input '#{line}'!" unless m
        cmd = m[1]; args = m[2]
        player_command(cmd, args) && return # Return if player_command found something and ran it.
        player_action(cmd, args) && return 
        puts "Unknown command."
      end
    end
    def player_command(command, args)
      if @@commands_ex.has_key? command
        cmd = @@commands_ex[command]
        return false if cmd[:allow] and not cmd[:allow].call(@player)
        cmd[:block].call(@player, command, args)
        true
      elsif @@commands.has_key? command
        method(@@commands[command]).call(@player, command, args)
        true
      else
        false
      end
    end
    def player_action(command, args)
      return false unless action = @player.find_action(command)
      action.invoke(@player, command, args)
      true
    end
    def puts(line)
      return if line.nil?
      @io.puts line if @io
    end
    def self.puts(line)
      @@connections.synchronize {
        @@connections.each_value {|session|
          session.puts line
        }
      }
    end
    def self.add_command(command, symbol)
      @@commands[command] = symbol
    end
    def self.load_modules(modified_after = Time.at(0))
      # FIXME: Should test for changes and then reload everything; otherwise old (bad) functions could remain in memory.
      Dir.open( MODULES ).each { |fn|
        next unless ( fn =~ /[.]rb$/ )
        path = MODULES+"/"+fn
        if File.mtime(path) > modified_after
          $server.log "Loading module #{path}"
          begin
            load path
          rescue => detail
            $server.error(detail)
          end
        end
      }
    end
    def self.cmd_last_desc=(text)
      @@cmd_last_desc = text
    end
    def self.cmd_last_help=(text)
      @@cmd_last_help = text
    end
    def self.cmd_last_allow=(block)
      @@cmd_last_allow = block
    end
    def self.cmd_add(args, &block)
      #symbol = args.keys.first
      #names = args.values.first[0]
      names = args.split ';'
      value = {:names=>names, :block => block, :desc => @@cmd_last_desc, :help => @@cmd_last_help, :allow => @@cmd_last_allow}
      names.each {|n|
        @@commands_ex[n] = value
      }
      @@cmd_last_desc = nil
      @@cmd_last_help = nil
      @@cmd_last_allow = nil
    end
    def self.commands
      @@commands_ex
    end
  end

  # Exception class to be used for errors that can be shown to the player.
  class UserError < RuntimeError
  end

  
end

# Old style command.
def add_command(command, symbol)
  RubyMUCK::Connection.add_command(command, symbol)
end

# New style commands.
def desc(text)
  RubyMUCK::Connection.cmd_last_desc = text
end
def help(text)
  RubyMUCK::Connection.cmd_last_help = text
end
def allow(&block)
  RubyMUCK::Connection.cmd_last_allow=(block)
end
def command(args, &block)
  RubyMUCK::Connection.cmd_add(args, &block)
end
