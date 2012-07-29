require 'singleton'
require 'monitor'
require 'config' # Since this should be required from ..
require 'lib/database'

module RubyMUCK
  
  Struct.new('Task', :name, :time, :block, :env)

  # Tasks may be defined using the following format:
  # 
  #   schedule_task 'name', :delay => 30 do |env|
  #     ...
  #     0
  #   end
  # 
  # The first parameter is the task name, which must be unique to the task.
  # (A task with the same name will be replaced by this one.)  The second
  # parameter is the initial env hash value.  It must contain a :delay
  # member, which describes how many seconds to wait before executing this
  # task.  Finally the task's block is given.  If it returns a non-zero number,
  # the same task will be rescheduled with that delay in seconds.  The env
  # hash will be retained (and may be used to keep state).
  class TaskManager
    include Singleton
    
    def initialize
      @tasks = []
      @tasks.extend(MonitorMixin)
      @new_task = @tasks.new_cond
      @thread = Thread.new { task_loop }
    end
    
    def add_task(name, env, &block)
      raise "Delay not specified on task #{name}." unless env.has_key? :delay
      #puts "Attempting to add task"
      @tasks.synchronize do
        kill name # This task will take the place of any old task by that name.
        @tasks << Struct::Task.new(name, Time.now+env[:delay], block, env) # owner is not used yet.
        @tasks.sort! {|a,b| a.time <=> b.time }
        @new_task.signal
        #puts "New task signalled"
      end
    end
    
    def task_by_name(name)
      @tasks.synchronize do
        return @tasks.select {|t| t.name == name}.first
      end
    end
    
    def invoke(name)
      @tasks.synchronize do
        task = task_by_name(name)
        return false unless task
        task.time = Time.now
        @tasks.sort! {|a,b| a.time <=> b.time }
        @new_task.signal
      end
      true
    end
    
    def kill(name)
      @tasks.synchronize do
        task = task_by_name(name)
        if task
          @tasks.delete task
          return true
        end
      end
      false
    end
    
    def task_loop
      loop do
        task_to_run = nil
      
        @tasks.synchronize do
          #puts "Waiting for task"
          @new_task.wait if @tasks.empty?
          if Time.now < @tasks.first.time
            next_task_time = (@tasks.first.time - Time.now).to_i + 1
            #puts "Waiting for task to start: #{next_task_time}"
            @new_task.wait next_task_time
          end
          task_to_run = @tasks.shift
        end
        
        next unless task_to_run
        
        # Now task_to_run should be ready!
        begin
          #puts "Executing #{task_to_run.name}:"
          delay = task_to_run.block.call(task_to_run.env)
          if delay and delay > 0
            task_to_run.env[:delay] = delay
            add_task(task_to_run.name, task_to_run.env, &task_to_run.block)
          end
        rescue => detail
          $server.error detail, "Error executing task '#{task_to_run.name}'"
        end
      end
    end
    
    def to_pretty
      out = ''
      @tasks.synchronize do
        max_name_length = @tasks.map {|t| t.name.length}.max 
        @tasks.each do |t|
          s = t.time - Time.now
          m = s/60
          s %= 60
          time = (m >= 1 ? "#{m.to_i}m" : '') + "#{s.to_i}s"
          out << "%-#{max_name_length}s %8s\n" % [t.name, time]
        end
      end
      out
    end
    
    def join
      @thread.join
    end
  end

end

def schedule_task(name, env, &block)
  RubyMUCK::TaskManager.instance.add_task(name, env, &block)
end

if $0 == __FILE__
  schedule_task 'boo', :delay => 5 do
    puts "Boo!"
    5
  end
  tm = RubyMUCK::TaskManager.instance
  puts tm.to_pretty
end
