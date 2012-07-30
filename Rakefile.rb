#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-26.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
require 'rake/testtask'
require_relative 'lib/object'
require_relative 'lib/server'
require_relative 'config'

include RubyMUCK

task :default => [:help]

desc "Displays this help information."
task :help do
  Rake::application.display_tasks_and_comments # Why won't this work?
  # Use rake -T instead.
end


desc "Run unit tests"
Rake::TestTask.new("test") { |t|
  t.pattern = 'test/tc_*.rb'
  #t.verbose = true
  t.warning = true
}

desc "Start the server"
task :run do
  #exec 'ruby ./rubymuck.rb'
  begin
    RubyMUCK::Server.run
  rescue => detail
    $stderr.puts detail
    $stderr.puts detail.backtrace[0..5].join("\n")
  end
end

desc "Export database to YAML."
task :exportyaml do
end

desc "Create a new database using parameters in config.rb."
task :newdb do
  # Build a fresh DB:
  # - Main Parent Room (ROOT_PARENT_ROOM)
  # - New Player Room (NEW_PLAYER_ROOM)
  # - Wizard
  puts "Creating New Database:"
  
  if File.exists? DATABASE_PATH
    n = -1
    begin
      n += 1
      new_name = DATABASE_PATH+n.to_s
    end while File.exists? new_name
    File.rename DATABASE_PATH, new_name
    puts "  Existing database moved to #{new_name}."
  end
  
  database.clear # Ensure that @@objects and @@players are empty.
  
  raise "ROOT_PARENT_ROOM not assigned!" unless ROOT_PARENT_ROOM
  parent = Room.new('Root Parent', ROOT_PARENT_ROOM)
  parent.desc = 'This is the default parent for all created rooms.  All actions here will be usable from child rooms.'
  puts "  Created parent room: #{parent}."
  
  raise "NEW_PLAYER_ROOM not assigned!" unless NEW_PLAYER_ROOM
  start = Room.new('New Player Room', NEW_PLAYER_ROOM)
  start.desc = 'This is the room that newly created players will appear in, and will have set as their home.'
  puts "  Created new player start room: #{start}."
  
  unless GUEST_ROOM
    puts "  SKIPPING guest room; not defined."
    guest = nil
  else
    guest = Room.new('Guest Room', GUEST_ROOM)
    guest.desc = 'This is the room that guests will appear in.'
    puts "  Created guest room: #{guest}."
  end
  
  god = Player.new('God')
  pw = Player.random_password
  god.password = pw
  god.owner = god
  god.where = start
  god.link = god.where
  god.set_flag :god, true
  god.set_flag :wizard, true
  god.set_flag :builder, true
  puts "  Created god character '#{god}' with password '#{pw}'.  WRITE THIS DOWN!"
  
  parent.owner = god
  start.owner = god
  
  puts "  Saving database to #{DATABASE_PATH}..."
  database.save
  puts "  ...done."
end

