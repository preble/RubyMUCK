#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-16.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
require 'yaml'
require 'benchmark'
require 'md5'
require 'config' # Since this should be required from ..
require 'lib/database'

module RubyMUCK

  # Regular expression portion for a legal object name.
  LGLOBJ = '[#\dA-Za-z\-_ ]+'
  ALL_FLAGS = [:player, :action, :room, :god, :wizard, :builder, :chown_ok, :dark, :quell]
  GOD_ONLY_FLAGS = [:god] # Flags that only Gods can set, but not Wizards.

  # The base RubyMUCK Object, which all game objects inherit.
  # Persistent state data is kept in the property tree, a path-accessible
  # structure (see #[] and #[]=).  The object's id is also stored.  All
  # other data is derived from this, including the 'cached' #contents.
  class Thing
    attr_reader :id
    attr_accessor :contents
    attr_reader :proptree
  
    def self.prop_accessor(prefix, *symbols)
      symbols.each {|sym|
        class_eval %{
          def #{sym}
            value = self['#{prefix}#{sym}']
            value.clone unless value.nil?
          end
          def #{sym}=(new_value)
            self['#{prefix}#{sym}'] = new_value
          end
        }
      }
    end
    def self.prop_id_accessor(prefix, *symbols)
      symbols.each {|sym|
        class_eval %{
          def #{sym}
            database.id_to_object(self['#{prefix}#{sym}'])
          end
          def #{sym}=(new_value)
            self['#{prefix}#{sym}'] = new_value.id_s
          end
        }
      }
    end
  
    prop_accessor '%/', :name, :desc
    prop_accessor '_', :succ, :osucc, :drop, :odrop, :fail, :ofail
    prop_id_accessor '%/', :owner, :link, :lock
  
    def initialize(name, id = nil, proptree = nil)
      raise "id must be >= 1." unless id.nil? or id >= 1
      raise "id already in use" if database.objects.has_key? id
      @id = id || database.next_id
      @proptree = proptree || {}
      @contents = []
      self.name = name unless name.nil?
      database.add self
    end
  

  
    # Returns an array of member variables to be saved when converting to YAML.
    def to_yaml_properties
      # Normal implementation: instance_variables.sort
      ["@id", "@proptree"]
    end
  
    # Implements dumping for Marshal.dump; returns a string.
    def _dump(depth)
      Marshal.dump :id => @id, :values => @proptree
    end
    # Return an Thing object.
    def self._load(string)
      h = Marshal.load string
      create h[:id], h[:values]
    end
    def self.create(id, proptree)
      new(nil, id, proptree)
    end
    
    def self.create_from_proptree(id, proptree)
      raise 'Property % missing.' unless proptree.has_key? '%'
      raise 'Property %/name missing.' unless proptree.has_key? '%'
      name = proptree['%']['name']
      flags = nil
      flags = proptree['%']['flags'] if proptree['%'].has_key? 'flags'
      return Action.new(name, id, proptree) if flags and flags.has_key?('action')
      return Player.new(name, id, proptree) if flags and flags.has_key?('player')
      return Room.new(name, id, proptree) if flags and flags.has_key?('room')
      Thing.new(name, id, proptree)
    end
  
    # Retrieves the property at the given path.  Example: @@_/name@@.
    def [](path)
      value = @proptree
      dirs = path.split('/')
      return value if dirs == [] # Root directory case.
      dirs[0..-2].each {|dir|
        unless value.has_key?(dir)
          return nil
        else
          value = value[dir]
        end
      }
      value[dirs[-1]]
    end
    # Assigns the property at the given path.  If the path does not exist, it will be created.
    # Should be used only by internally-controlled routines.  Routines that involve external
    # data being controlled by the user should use #set_prop.
    def []=(path, value)
      raise "Path must be a string." unless path.class == String
      raise "Value must be a string or nil." unless (value.class == String or value.nil?)
      hash = @proptree
      dirs = path.split('/')
      dirs[0..-2].each {|dir|
        unless hash.has_key?(dir)
          hash[dir] = Hash.new
        end
        hash = hash[dir]
      }
      if value.nil?
        hash.delete dirs[-1]
      else
        hash[dirs[-1]] = value
      end
      database.notify_changed(self)
    end
    # #[]= for use by routines involving user input, where the path has been set by the user.
    def set_prop(me, path, value)
      return false unless me.can_write_prop?(self, path)
      self[path] = value
      true
    end
    def get_prop(me, path)
      return nil unless me.can_read_prop?(self, path)
      self[path]
    end
  
    # Returns a string representation of this object, usually including its id: "ObjectName(#12345)".
    def to_s
      "#{name}(##{id})"
    end
    # Returns a string representation of this object's id: "#12345".
    def id_s
      "##{id}"
    end
  
    def delete
      # Delete this object.
      self.where.contents.delete self unless self.where.nil?
      database.delete self
    end
  
    # Returns the object representing the location of this object.  If no location has been assigned,
    # or if the location does not exist, @@nil@@ is returned.
    # This value is stored as an id string in '_/where'.
    def where
      database.id_to_object(self['%/where'])
    end
    # Assigns the location of this object and updates #contents on the old and new location objects.
    def where=(new_where)
      old_where = database.id_to_object(self['%/where'])
      old_where.contents.delete self unless old_where.nil?
      self['%/where'] = new_where.id_s
      database.id_to_object(self['%/where']).contents << self
    end
  
    def has_flag?(flag)
      flag = flag.to_sym if flag.is_a? String
      raise "Invalid flag" unless ALL_FLAGS.include? flag
      path = "%/flags/#{flag}"
      self[path] == '1'
    end
    def set_flag(flag, on)
      flag = flag.to_sym if flag.is_a? String
      raise "Invalid flag" unless ALL_FLAGS.include? flag
      path = "%/flags/#{flag}"
      self[path] = on ? '1' : '0'
    end
    def flags
      return [] unless self['%/flags']
      self['%/flags'].select {|flag, value|
        value == '1'
      }.map {|k|
        k[0].to_sym
      }
    end
  
    # True if this object is an Action.
    def action?
      false
    end
    # True if this object is a Player.
    def player?
      false
    end
    def room?
      false
    end
  
    # Send text to this object.
    def tell(text)
      # Does nothing.
    end
  
    # Get text representing the output of looker looking at this object.
    def get_look(looker)
      unless self.action?
        output = look_name(looker)+"\n"
      else
        output = ''
      end
      output << (desc||'You see nothing special.')+"\n"
    
      if contents.length > 0
        if self.player?
          output += "Carrying:\n"
        else
          output += "Contents:\n"
        end
        output += visible_objects(looker).map{|obj| obj.look_name(looker)}.join("\n")+"\n"
      end
      output
    end
  
    # Returns the name of this object to be shown when viewing rooms, contents, etc.
    def look_name(looker)
      if looker == self.owner or (looker.player? and looker.wizard?)
        flags = ''
        flags += 'P' if has_flag? :player
        flags += 'R' if has_flag? :room
        flags += 'E' if has_flag? :action
        "#{name}(##{id}#{flags})"
      else
        name
      end
    end
  
    # Returns the action corresponding to word in this object or any of the objects it is located in (recursively).
    def find_action(word)
      @contents.each {|obj|
        next unless obj.action?
        return obj if obj.name.split(';').include?(word)
      }
      return where.find_action(word) unless where.nil?
      nil
    end
  
    # Returns an array of objects visible to the specified player in this object.
    def visible_objects(me)
      objects = []
      dark = has_flag?(:dark)
      contents.each {|obj|
        next if obj.action?
        next if dark and me.wizard? == false and obj.owner != me
        objects << obj
      }
      objects
    end
  
    # True if this object is visible to the object specified.
    def visible_to?(me)
      me.where == self.where or me == self.where
    end
    
    
    
    # Filter text for any programming or pronouns.
    def filter(me, text, args)
      return text if text.nil? or text.empty?
      
      # If it contains any interpreted code...
      if text.index '<%'
        parser = Parser.instance
        begin
          parser.var_this = self
          parser.var_me = me
          out = text.gsub(/<%(.*?)%>/) {|interp| parser.parse($1) }
        ensure
          parser.release
        end
      else
        # No interpreted code.
        out = text
      end
      
      # Escape sequence decoding:
      out = out.gsub(/%[A-Za-z]/) {|esc| Thing.decode_escape(esc[1..-1], me, self) }
      
      return nil if out.empty? # To allow the 'or's to work in the code that calls this method.
      out
    end
    
    GENDER_PRONOUNS = {
      :male   => {:s => 'he', :o => 'him', :p => 'his', :a => 'his'},
      :female => {:s => 'she', :o => 'her', :p => 'her', :a => 'hers'},
      :neuter => {:s => 'it', :o => 'it', :p => 'its', :a => 'its'},
      :plural => {:s => 'they', :o => 'them', :p => 'their', :a => 'theirs'},
      :spivak => {:s => 'e', :o => 'em', :p => 'eir', :a => 'eirs'}
    }
    def self.decode_escape(escape, me, this)
      gender = me['_gender']
      return me.name if gender.nil? or gender.empty? or !GENDER_PRONOUNS.has_key?(gender.downcase.to_sym)
      pronouns = GENDER_PRONOUNS[gender.downcase.to_sym]
      return "%#{escape}" unless pronouns.has_key?(escape.downcase.to_sym) # Do no translation if escape is not understood.
      sub = pronouns[escape.to_sym]
      sub.capitalize! if escape.downcase != escape
      sub
    end
    
  end



  # Represents a Player Thing.
  class Player < Thing
  
    attr_accessor :last_activity
  
    def initialize(name, id=nil, proptree=nil)
      super(name, id, proptree)
      set_flag :player, true
      database.players[self.name.downcase] = self # Use self.name because 'name' may be null if called from self.create.
      @cached_name = nil
      @last_activity = nil
      @io = []
      self.owner = self
    end
  
    def delete
      super
      # Delete this object.
      database.players.delete(self.name.downcase) unless self.name.nil?
    end
  
    def name=(new_name)
      database.players.delete(self.name.downcase) unless self.name.nil?
      super(new_name)
      database.players[new_name.downcase] = self
    end
  
    def player?
      true
    end
    def online?
      !@io.empty?
    end
    # True if the player is a Wizard *or better* (including God).
    def wizard?
      (self.has_flag?(:wizard) or self.has_flag?(:god)) and (self.has_flag?(:quell) == false)
    end
    
    def idle_string
      return 'Asleep' unless online?
      last_connect = Time.at(self['%/last_connect'].to_i) # Use last_connect in case the player has not had any activity this session.
      distance_of_time_in_words_short(self.last_activity || last_connect, Time.now, true)
    end
  
    # Attempts to log in the specified player by name and password.
    # Returns the Player object if it was successful; otherwise returns nil.
    def Player.login(username, password)
      return nil unless password and not password.empty?
      player = database.players[username.downcase]
      return nil unless player
      # Super-insecure to start with.  FIXME: Use MD5 hash?
      return nil unless player.check_password(password)
      player
    end
  
    # Recommend changing this BEFORE creating any players.
    @@salt = 'salty' # Should change to SALT global const?
  
    # True if the supplied password is valid for this player.
    def check_password(pw)
      self['%/password'] == (MD5.new(pw + @@salt).to_s)
    end
  
    # Assigns the password for this Player.  Returns True if successful (if the old password matches).
    def password(new_pw, old_pw)
      return false unless check_password(old_pw)
      self['%/password'] = (MD5.new(new_pw + @@salt).to_s)
      true
    end
  
    def password=(new_pw)
      self['%/password'] = (MD5.new(new_pw + @@salt).to_s)
    end
  
    # Assigns the IO object for this player's #tell messages.  A value of nil should be passed if the player has disconnected.
    # Also updates state appropriately and performs "X has connected." and "X has disconnected." notifications.
    def add_io(io)
      return if @io.include? io
      raise "Null io added" if io.nil?
      otell = self.name+' has connected.'
      self['%/last_connect'] = Time.now.to_i.to_s # Decode with Time.at(value.to_i)
      tell_others_in_room(otell)
      @io << io
    end
    def remove_io(io)
      return unless @io.include? io
      raise "Null io remove" if io.nil?
      otell = self.name+' has disconnected.'
      self['%/last_disconnect'] = Time.now.to_i.to_s
      tell_others_in_room(otell)
      @io.delete io
    end

    # Send a line of text to this Player.  If the line does not have a newline character at the end, one will be added.
    def tell(text)
      if @io && !@io.empty?
        @io.each  do |io|
          if io.closed?
            @io.delete io
          else
            if text.include? "\n"
              io.puts text
            else
              io.puts wrap_text(text, 78)
            end
          end
        end
      end
    end
  
    # Sends a line to all other Players in the room.
    def tell_others_in_room(text)
      where.contents.each {|roommate|
        roommate.tell(text) if roommate != self
      }
    end
    
    # Present the player with a series of one-line questions.
    # Input: [[:key1, 'Prompt1?'], [:key2, 'Prompt2?'], ...]
    # Output: {:key1 => 'Answer1', :key2 => 'Answer2'}
    def interview(questions)
      return nil unless @io
      answers = {}
      questions.each {|key, prompt|
        tell prompt
        line = @io.gets
        return nil unless line
        answers[key] = line.strip
      }
      answers
    end
  
    # Generates a random password string.
    # From: http://snippets.dzone.com/posts/show/2137
    def Player.random_password(size = 8)
      chars = (('a'..'z').to_a + ('0'..'9').to_a) - %w(i o 0 1 l 0)
      (1..size).collect{|a| chars[rand(chars.size)] }.join
    end
  
    def look(what = nil)
      if what.nil? or what.empty?
        tell(where.get_look(self))
      else
        obj = text_to_object what
        raise UserError, "I don't see that here." unless obj # TODO: Look security needs to be tightened down.
        tell obj.get_look(self)
        obj.tell self.name+" looked at you.\n" unless obj == self
      end
    end
    def text_to_object(text)
      database.text_to_object(text, self)
    end
    def can_modify?(obj)
      self.has_flag?(:god) or self.wizard? or obj.owner == self
    end
    def can_write_prop?(obj, prop)
      #$stderr.puts "Checking #{prop}"
      # can_modify and (not in protected directory OR wizard)
      # Name and Where cannot be set manually.
      can_modify?(obj) and (prop.match('^/?%(/|$)').nil? or self.wizard?) and (prop.match("/?%/(name|where)").nil?)
    end
    def can_read_prop?(obj, prop)
      #$stderr.puts "Checking #{prop}"
      # can_modify and (not in protected directory OR wizard)
      return true if self.wizard?
      return false if prop.match('^/?%(/|$)')
      obj.owner == self or prop.match('^/?_').nil?
    end
    def can_set_flag?(obj, flag)
      return false unless can_modify?(obj)
      return true if self.has_flag? :god
      return true if self.wizard? and GOD_ONLY_FLAGS.include?(flag) == false
      return true if (self.has_flag? :wizard or self.has_flag? :god) && flag == :quell
      # Since the above statements have handled flags restricted to only Gods and Wizards,
      # the case statement below will only deal with those not covered.
      case flag
        when :chown_ok
          obj.owner == self
        when :dark
          # Cannot set dark on objects in a room that you don't own.
          obj.owner == self and (obj.where.owner == self or obj.room?)
        else
          false
      end
    end
  end


  class Action < Thing
    def initialize(name, id = nil, proptree = nil)
      super name, id, proptree
      set_flag :action, true
    end
    def action?
      true
    end
    def unlocked?(me)
      true
    end
    def invoke(me, cmd, args)
      if link and unlocked?(me)
        me.tell filter(me,succ,args) unless succ.nil? or succ.empty?
        me.tell_others_in_room me.name+" "+(filter(me,osucc,args) || "has left.")
        me.where = link
        me.tell filter(me,drop,args) unless drop.nil? or drop.empty?
        me.tell_others_in_room me.name+" "+(filter(me,odrop,args) || "has arrived.")
        me.look
      else
        me.tell filter(me,fail,args) || 'You can\'t go that way.'
        me.tell_others_in_room ofail unless filter(me,ofail,args)
      end
    end
  end

  class Room < Thing
    def initialize(name, id = nil, proptree = nil)
      super name, id, proptree
      set_flag :room, true
    end
    def room?
      true
    end
  end

end