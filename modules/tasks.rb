#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-16.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
#

desc 'Display scheduled tasks.'
allow { |me| me.wizard? }
command '@tasks;@ps' do |me,cmd,args|
  me.tell 'Tasks/Next Run'
  me.tell TaskManager.instance.to_pretty
end

desc 'Cancel a scheduled task.'
allow { |me| me.wizard? }
command '@kill' do |me,cmd,args|
  result = TaskManager.instance.kill(args)
  raise UserError, 'No such task.' unless result
  me.tell 'Killed.'
end

desc 'Invoke a scheduled task NOW.'
allow { |me| me.wizard? }
command '@now' do |me,cmd,args|
  result = TaskManager.instance.invoke(args)
  raise UserError, 'No such task.' unless result
  me.tell 'Invoked.'
end

# schedule_task 'reloader', :delay => 60, :last_check => Time.now do |env|
#   Connection.load_modules env[:last_check]
#   env[:last_check] = Time.now
#   60
# end

# Send a line of text to everybody.
def wall(text)
  database.each_player do |p|
    next unless p.online?
    p.tell text
  end
  text
end

# dbsaver - Task for performing traditional (blocking) database saves.
# Not used if DATABASE_MIRRORED is true.  Note that there is presently no
# method for blocking users from making changes while this is running, 
# therefore it is possible that consistency errors could arise.
# Math in order to make the saves happen in time with the clock. (on the half hour, hour, etc.)
first_db_save = (DATABASE_SAVE_PERIOD)-(Time.now.to_i % (DATABASE_SAVE_PERIOD))-60
schedule_task 'dbsaver', :delay => first_db_save do |env|
  env[:state] = :wait unless env.has_key? :state
  case env[:state]
  when :wait
    wall "## Saving the database in one minute!"
    env[:state] = :save
    60
  when :save
    wall '## Saving the database...'
    $server.log 'Saving database...'
    database.save
    $server.log 'Done saving database.'
    wall '## Done.'
    env[:state] = :wait
    next_save = (DATABASE_SAVE_PERIOD)-(Time.now.to_i % (DATABASE_SAVE_PERIOD))
    next_save-60
  else
    raise "Unknown state: #{env[:state]}"
  end
end unless DATABASE_MIRRORED

# mirrorsaver - Task for triggering mirrored database saves.  Note that
# this task does not block, and it is only used if DATABASE_MIRRORED is true.
schedule_task 'mirrorsaver', :delay => DATABASE_SAVE_PERIOD do |env|
  database.save_mirror false # Do not block; the whole point of the mirrored DB is to avoid blocking (evan tasks).
  DATABASE_SAVE_PERIOD
end if DATABASE_MIRRORED
