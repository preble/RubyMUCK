#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-16.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
require 'yaml'
require 'benchmark'
require 'digest/md5'
require 'monitor'
require 'singleton'
require_relative '../config'

module RubyMUCK
  # Encapsulates the RubyMUCK database.
  # Provides two methods of saving the database: traditional and mirrored.
  # The traditional style (invoked with #save) is similar to TinyMU* in that
  # it is a blocking operation while the database is saved to preserve 
  # consistency.  
  # Important: While the call blocks, player's actions are not presently 
  # blocked.
  # The mirrored style adds on to the basic database by maintaining a copy
  # of it in memory.  Object changes are propogated to the mirror through a
  # queue.  The database can then be saved 1) in the background, 2) without 
  # allowing changes to it until the save is complete, and 3) without losing
  # any changes.  The mirrored style is recommended, and is enabled (by 
  # default) using DATABASE_MIRRORED in config.rb.
  class Database
    include Singleton
    def initialize
      if DATABASE_MIRRORED
        @mirror = {} # Holds copy of the database.
        @mirror.extend(MonitorMixin)
        
        @mirror_queue = {} # Holds the list of changed items to be updated in the mirror.
        @mirror_queue.extend(MonitorMixin)
        @mirror_queued = @mirror_queue.new_cond # Signalled when something has been added to the queue.
        Thread.new { queue_loop }
      end
      clear
    end
    
    # Empty the database of all objects.
    def clear
      @players = {}
      @objects = {}
      @avail_ids = nil
      if DATABASE_MIRRORED
        @mirror.synchronize do
          @mirror.clear
        end
        @mirror_queue.synchronize do
          @mirror_queue.clear
          @mirror_queued.signal
        end
      end
    end
    
    # Rebuilds the caches.
    def rebuild
      # Now need to build @@players and contents for each object!
      @players = {}
      # Clear out all contents before starting.
      @objects.each_value do |obj|
        obj.contents = []
      end
      # Rebuild contents.
      @objects.each_value {|obj|
        @players[obj.name.downcase] = obj if obj.player?
        obj.contents = [] unless obj.contents
        if where = obj.where
          where.contents = [] unless where.contents
          where.contents << obj
        end
        if obj.where.nil? and not obj['%/where'].nil?
          log("Warning: Object #{obj} has an invalid _/where value.")
        end
        # Test for integrity issues.
        if obj.player? and where.nil?
          log("Warning: Player #{obj} has no 'where'.")
        end
        if obj.link.nil? and not obj['%/link'].nil?
          log("Warning: Object #{obj} has an invalid _/link value.")
        end
        # TODO: Test that any #xxxxx refs are to objects that exist.
      }
    end
    
    # Method allowing a changed object to notify the database that it has
    # changed.  This is used by the mirrored database system.
    def notify_changed(object)
      if DATABASE_MIRRORED
        @mirror_queue.synchronize do
          @mirror_queue[object.id] = Marshal.load(Marshal.dump(object.proptree))
          @mirror_queued.signal
        end
      end
    end
    
    # Loop to move queued objects (previously duplicated) into the mirrored
    # database.
    def queue_loop
      loop do
        @mirror_queue.synchronize do
          @mirror_queued.wait
        end
        sleep 0.05 # Wait a bit in order to let several modifications slip in.
        @mirror_queue.synchronize do
          next if @mirror_queue.empty?
          @mirror.synchronize do
            @mirror_queue.each do |id, tree|
              if tree
                @mirror[id] = tree
              else
                @mirror.delete id
              end
            end
            @mirror_queue.clear
          end
        end
      end         
    end
    
    # Actually saves the mirrored database.  
    # Called by #save_mirror.
    def do_save_mirror
      @mirror.synchronize do
        $server.log 'Mirror: Saving...'
        File.open(DATABASE_PATH, 'w') do |stream|
          case DATABASE_FORMAT
          when :yaml
            YAML.dump @mirror, stream
          when :dump
            @mirror.each do |id, proptree|
              stream << Marshal.dump([id, proptree])
            end
          else
            $server.log "Database format #{format} unsupported by mirrored DB!"
          end
        end
        $server.log 'Mirror: Saved.'
      end
    end if DATABASE_MIRRORED
    
    # Saves the mirror database to disk.  Optionally blocking.
    def save_mirror(blocking = true)
      if blocking
        do_save_mirror
      else
        Thread.new { do_save_mirror }
      end
    end if DATABASE_MIRRORED
    
    def save(path = DATABASE_PATH, format = DATABASE_FORMAT)
      File.open(path, 'w') do |stream|
        case format
        when :oldyaml
          $stderr.puts "WARNING: Database format #{format} is not recommended!"
          YAML.dump @objects, stream
        when :yaml
          h = {}
          @objects.each{|id,obj| h[id] = obj.proptree }
          YAML.dump h, stream
        when :olddump
          $stderr.puts "WARNING: Database format #{format} is not recommended!"
          Marshal.dump @objects, stream
        when :dump
          # Dump each object as a two element array of the id and the proptree Hash.
          @objects.each_value do |obj|
            stream << Marshal.dump([obj.id, obj.proptree])
          end
        else
          raise "Unknown database format: #{format}"
        end
      end
    end
    
    def load(path = DATABASE_PATH, format = DATABASE_FORMAT)
      File.open(path, 'r') do |stream|
        clear # Empty the database.
        case format
        when :oldyaml
          @objects = YAML.load stream
        when :yaml
          (YAML.load stream).each {|id,proptree|
            Thing.create_from_proptree(id, proptree)
          }
        when :olddump
          @objects = Marshal.load stream
        when :dump
          until stream.eof?
            id, proptree = Marshal.load stream
            Thing.create_from_proptree(id, proptree)
          end
        else
          raise "Unknown database format: #{format}"
        end
        rebuild # Rebuild caches.
      end
    end
    
    
    # Returns the next available object id.
    def next_id
      unless @avail_ids
        # Build @@avail_ids.
        @avail_ids = []
        id = 1
        @objects.keys.sort.each do |existing_id|
          while id < existing_id
            @avail_ids << id
            id += 1
          end
          id += 1 # Skip over existing_id.
        end
        @avail_ids << id # id should now be 1 higher than the last used id.
      end
      new_id = @avail_ids.shift
      if @avail_ids.empty?
        @avail_ids.unshift new_id + 1
      end
      new_id
    end
    
    def add(object)
      @objects[object.id] = object
      notify_changed object
    end
    
    def delete(object)
      @objects.delete object.id
      @avail_ids << object.id
      if DATABASE_MIRRORED
        @mirror_queue.synchronize do
          @mirror_queue[object.id] = nil # A nil signifies that this object should be removed from the mirror.
          @mirror_queued.signal
        end
      end
      # @@avail_ids.sort! # Not going to sort in order to make newest-deleted ids be last-reallocated.
    end
    
    # Finds an object with a name starting with text in the room given location (where) visible to me.
    # Returns one object; if there are multiple matches, nil is returned.
    # text should be in lowercase.
    def text_to_object_in(text, me, where)
      text = Regexp.escape(text)
      count = 0
      contender = nil
      where.contents.map {|obj|
        if obj.name.downcase.match('^'+text) and obj.visible_to?(me)
          contender = obj
          count += 1
        end
      }
      if count == 1
        return contender
      elsif count > 1
        return nil
      end
    end

    # Finds the object referred to by text visible to me.
    # Returns one object; if there are multiple matches, nil is returned.
    def text_to_object(text, me)
      text = text.downcase.strip
      if text == 'me'
        return me
      elsif text == 'here'
        return me.where
      elsif text.match(/^#([0-9]+)/)
        return id_to_object(text)
      elsif m = text.match(/^\$(.*)/)
        # An ID alias name.
        resolved = me["_idaliases/#{m[1]}"]
        if resolved and obj = id_to_object(resolved)
          return obj
        else
          return nil
        end
      else
        # Check the player's inventory
        obj = text_to_object_in(text, me, me)
        return obj unless obj.nil?
    
        # It must be something in the room?
        obj = text_to_object_in(text, me, me.where)
        return obj unless obj.nil?
      end
      nil
    end
    
    # Finds the object with the given id.  Accepts Fixnum and String ("#12345") formats.
    def id_to_object(id)
      return nil unless id
      id = id.strip[1..-1].to_i unless id.class == Fixnum
      raise "Invalid id" if id == 0
      @objects[id]
    end
    # Returns the Hash of all objects, keyed by the numeric id of the object.
    def objects
      @objects
    end
    # Calls block for each player in the database.
    def each_player
      @players.each_value {|obj|
        yield obj
      }
    end
    # Returns the Hash for all players, keyed by the lowercase Player name.
    def players
      @players
    end
    # Finds the Player with the exact name specified.
    def player_by_name(name)
      name = name.downcase # Don't use downcase! here so as to avoid corruption of object.
      if @players.has_key? name
        return @players[name]
      else
        return nil
      end
    end

  end

  def database
    Database.instance
  end
end
