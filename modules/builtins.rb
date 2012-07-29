#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-16.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
#
#  Built-in Module containing basic command implementations.
#

# From the TextMate blog: http://macromates.com/blog/2006/wrapping-text-with-regular-expressions/
def wrap_text(txt, col = 80)
  txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
    "\\1\\3\n")[0..-2]
end
# Improvised:
def wrap_indent_text(txt, col = 75, indent = 2)
  txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
    "\\1\\3\n#{' '*indent}")[0..-4]
end

def assert_perm_to_modify(me, obj, message = 'Permission denied.')
  raise UserError, message unless me.can_modify? obj
end
def assert_perm_to_link_to(me, obj, message = 'Linking permission denied.')
  assert_perm_to_modify(me, obj, message) # FIXME
end

desc 'Describes and shows the contents of your surroundings.'
help 'Usage: look [object|here|me]'
command 'look;l' do |me,cmd,what|
  raise "look called with blank who." unless me
  raise "who has no location" unless me.where
  me.look(what)
end

def cmd_name(me, cmd, args)
  m = args.match(/(.*?)=(.*)/)
  raise UserError, "Syntax: #{cmd} <object>=<name>" unless m

  target = m[1]
  new_name = m[2]
  obj = me.text_to_object target
  raise UserError, "Could not find object '#{target}'." unless obj
  assert_perm_to_modify(me, obj)

  obj.name = new_name
  me.tell "Name set."
end

def cmd_desc(me, cmd, args)
  m = args.match(/(.*?)=(.*)/)
  raise UserError, "Syntax: #{cmd} <object>=<description>" unless m

  target = m[1]
  new_desc = m[2]
  obj = me.text_to_object target
  raise UserError, "Could not find object '#{target}'." unless obj
  assert_perm_to_modify(me, obj)

  obj.desc = new_desc
  me.tell "Description set.\n"
end

desc 'Set success, drop, and fail messages.'
help <<-EOH
Usage: CMD <object>=<message>
Descriptions:
  @succ  - Message shown to player on successful execution of the action
           this message is attached to.
  @osucc - Message shown to others in the start room on successful action.
  @drop  - Message shown to player on successful execution of an action,
           once the player has been moved into a new room by the action.
  @odrop - Message shown to others in the finish room of a successful 
           action.
  @fail  - Message shown to player when an action fails to execute.
  @ofail - Message shown to others in the room when an action fails to 
           execute.
EOH
command '@succ;@osucc;@drop;@odrop;@fail;@ofail' do |me, cmd, args|
  cmd = cmd[1..-1]
  raise "cmd_dropsuccfail with unknown cmd" unless ['drop','odrop','succ','osucc','fail','ofail'].include? cmd
  m = args.strip.match /(.*?)\s*=\s*(.*)/
  raise UserError, "Usage: #{cmd} <object>=<text>" unless m
  
  obj_text = m[1]
  field_text = m[2]
  obj = me.text_to_object obj_text
  raise UserError, "Could not find object '#{obj_text}'." unless obj
  assert_perm_to_modify(me, obj)
  
  field_text = nil if field_text.empty?
  obj.method(cmd+'=').call(field_text)
  me.tell field_text.nil? ? "Property cleared." : "Property set."
end

def cmd_link(me, cmd, args)
  m = args.match(/(.*?)=(.*)/)
  raise UserError, "Syntax: #{cmd} <object to link>=<object to be linked to>" unless m
  
  link_this = me.text_to_object m[1]
  raise UserError, "Could not find object '#{m[1]}'." unless link_this
  assert_perm_to_modify(me, link_this)

  to_this = me.text_to_object m[2]
  raise UserError, "Could not find object '#{m[2]}'." unless to_this
  assert_perm_to_link_to(me, to_this)
  
  link_this.link = to_this
  me.tell "Linked."
end

def cmd_prop(me, cmd, args)
  syntax = "Syntax: #{cmd} <object>/<path/to/property>[=<value>]"
  raise UserError, syntax if args.empty?
  if not args.include? '/'
    # Print listing at root: 'prop me'
    target = me.text_to_object args
    raise UserError, "I don't see that here." unless target
    assert_perm_to_modify(me, target)
    cmd_prop_print(me, target, '')
  elsif args.empty? == false
    if args.include? '='
      # Assignment: 'prop here/x/y/z=abc'
      m = args.match /(.*?)(\/(.*?))(=(.*))/ # m[1] == object, m[3] = path/to/property m[5] = value
      raise UserError, syntax unless m
      target = me.text_to_object m[1]
      raise UserError, "I don't see that here." unless target
      raise UserError, "Permission denied." unless target.set_prop(me, m[3], m[5])
      me.tell "Property set."
    else
      # Show: 'prop here/x/y/z'
      m = args.match "(#{LGLOBJ})(?:\/(.*))" # m[1] == object, m[3] = path/to/property
      raise UserError, syntax unless m
      target = me.text_to_object m[1]
      raise UserError, "I don't see that here." unless target
      assert_perm_to_modify(me, target)
      cmd_prop_print(me, target, m[2])
    end
  end
end

def cmd_prop_print(me, obj, path)
  me.tell "Properties on #{obj} in '#{path}':"
  tree = obj[path]
  prop_count = 0
  if tree.class == Hash
    max_key_length = tree.keys.map{|k| k.length}.max
    tree.sort.each {|key, value|
      next unless me.can_read_prop?(obj, path+'/'+key)
      me.tell cmd_prop_single(key, value, max_key_length)
      prop_count += 1
    }
  elsif me.can_read_prop?(obj, path) and not tree.nil?
    me.tell cmd_prop_single(path,tree)
    prop_count += 1
  end
  me.tell "#{prop_count} properties."
end
def cmd_prop_single(path, value, padding=10)
  if value.class == Hash
    value = "(directory: #{value.length})"
  elsif value.nil?
    value = 'nil'
  else
    value = value.to_s
  end
  "  %-#{padding}s: %s" % [path, value]
end


def cmd_chown(me, cmd, args)
  m = args.match "(#{LGLOBJ})(?:=(#{LGLOBJ}))?"
  raise UserError, "Usage: #{cmd} <object>[=<new owner>]" unless m
    
  obj = me.text_to_object m[1]
  raise UserError, "I don't see that object here: '#{m[1]}'" unless obj
  
  raise UserError, "Permission denied." unless me.can_modify?(obj) or obj.has_flag?(:chown_ok)
  
  if m[2].nil?
    obj.owner = me
  else
    new_owner = me.text_to_object m[2]
    raise UserError, "I don't see that player here: '#{m[2]}'" unless new_owner and new_owner.player?
    obj.owner = new_owner
  end
  
  me.tell "Owner set."
end


# Adaptation of Ruby on Rails' distance_of_time_in_words()
def distance_of_time_in_words_short(from_time, to_time = 0, include_seconds = false)
  to_time = Time.now if to_time == 0
	distance_in_minutes = (((to_time - from_time).abs)/60).round
	distance_in_seconds = ((to_time - from_time).abs).round

	case distance_in_minutes
	  when 0..1
	    return (distance_in_minutes == 0) ? '<1m' : '1m' unless include_seconds
	    case distance_in_seconds
        when 0      then '0s'
	      when 1..4   then '<5s'
	      when 5..9   then '<10s'
	      when 10..19 then '<20s'
	      when 20..39 then '~30s'
	      when 40..59 then '<1m'
	      else             '1m'
	    end

	  when 2..44           then "#{distance_in_minutes}m"
	  when 45..89          then '1h'
	  when 90..1439        then "#{(distance_in_minutes.to_f / 60.0).round}h"
	  when 1440..2879      then '1d'
	  else                 "#{(distance_in_minutes / 1440).round}d"
	end
end

desc 'Display a list of players in this room.'
command 'ws' do |me,cmd,args|
  players = me.where.contents.select {|obj| obj.player? }.sort {|a,b| a.name <=> b.name }
  #        0        1         2         3          4        5         6         7
  #        12345678901234567890123456789012345678901234567890123456789012345678901234567890
  me.tell '__Name______________Idle___Sex______Species_______________________________'
  players.each do |p|
    sex = p['_sex'] || p['_gender'] || 'Unknown'
    species = p['_species'] || 'Unknown'
    me.tell '  %-17s %-6s %-8s %s' % [p.name, p.idle_string, sex, species]
  end
end

desc 'Display a list of who is online.'
command 'who;WHO' do |me,cmd,args|
  if not args.empty?
    m = args.match /#status\s+(.*)/
    raise UserError, "Usage: #{cmd} [#status <message>]" unless m
    me['_status'] = m[1]
    me.tell 'Status updated to: '+me['_status']
    return
  end
  #        0        1         2         3          4        5         6         7
  #        12345678901234567890123456789012345678901234567890123456789012345678901234567890
  me.tell "__Name____________Idle____Status___(update with 'status <message>')_______"
  count = 0
  database.each_player {|player|
    next unless player.online?
    status = player['_status'] || ''
    me.tell '  %-15s %-4s    %-30s' % [player.name, player.idle_string, status]
    count += 1
  }
  me.tell "- #{count} players online - "
end

desc 'Set or query your Status field (displayed in who).'
help 'CMD [status text]; CMD clear to clear status.'
command 'status' do |me,cmd,args|
  if args and args.empty? == false
    args = nil if args == 'clear'
    me['_status'] = args
  end
  me.tell "Status: #{me['_status'] or ''}"
end

desc 'Send your player home.'
command 'home;gohome' do |me, cmd, args|
  raise UserError, "No home set.  Set it with '@link me=here'." unless me.link
  me.tell "There's no place like home...\n"*3
  me.tell_others_in_room "#{me.name} goes home."
  me.where = me.link
  me.look
  me.tell_others_in_room "#{me.name} has arrived."
end

def cmd_action(me, cmd, args)
  raise UserError, 'Permission denied.' unless me.has_flag? :builder
  # action <object>=<action name>
  m = args.match "(.+)=(#{LGLOBJ})"
  raise UserError, "Usage: #{cmd} <link name>=<location of link>" unless m
  
  action_name = m[1]
  location = m[2]
  location_obj = me.text_to_object location
  raise UserError, "Could not find location '#{location}'" unless location_obj
  assert_perm_to_modify(me, location_obj)
  
  action = Action.new(action_name)
  action.where = location_obj
  action.owner = me
  me.tell "Action created: #{action.id_s}"
end

def cmd_open(me, cmd, args)
  raise UserError, 'Permission denied.' unless me.has_flag? :builder
  # open <action name>=<destination>
  m = args.match "(.+)=(#{LGLOBJ})"
  raise UserError, "Usage: #{cmd} <action name>=<destination>" unless m

  action_name = m[1]; dest = m[2]
  dest_obj = me.text_to_object dest
  raise UserError, "Could not find destination '#{dest}'." unless dest_obj
  assert_perm_to_modify(me, me.where, 'You cannot create an action here.')
  assert_perm_to_link_to(me, dest_obj, 'You cannot link there.')

  action = Action.new(action_name)
  action.where = me.where
  action.link = dest_obj
  action.owner = me
  me.tell "Action #{action} created and linked to #{action.link}."
end

def cmd_dig(me, cmd, args)
  raise UserError, 'Permission denied.' unless me.has_flag? :builder
  raise UserError, "Usage: #{cmd} <room name>" if args.nil? or args.empty?
  args.strip!
  raise UserError, "Name contains invalid characters." unless args.match LGLOBJ
  
  room = Room.new(args.strip)
  room.owner = me
  room.where = database.id_to_object(ROOT_PARENT_ROOM)
  me.tell "Room #{room} created."
end

def cmd_create(me, cmd, args)
  raise UserError, 'Permission denied.' unless me.has_flag? :builder
  raise UserError, "Usage: #{cmd} <obj name>" if args.nil? or args.empty?
  args.strip!
  raise UserError, "Name contains invalid characters." unless args.match LGLOBJ

  obj = Thing.new(args)
  obj.where = me
  obj.owner = me
  me.tell "Object #{obj} created.  It is in your inventory."
end

def cmd_delete(me, cmd, args)
  raise UserError, 'Permission denied.' unless me.has_flag? :builder
  raise UserError, "Usage: #{cmd} <obj name>" if args.nil? or args.empty?
  args.strip!
  raise UserError, "Name contains invalid characters." unless args.match LGLOBJ
  
  obj = me.text_to_object args
  raise UserError, "Cannot find object." unless obj
  assert_perm_to_modify(me, obj)
  raise UserError, "Object is not empty." unless obj.contents.empty?
  obj.delete
  # What about objects that were inside this object?  Objects that link to this object?  Etc.
  me.tell "Deleted."
end

desc 'Change your password.'
help 'CMD <old password>=<new password>'
command '@password' do |me, cmd, args|
  m = args.match /(.*)\s*=\s*(.*)/
  raise UserError, 'Incorrect password.' unless me.password(m[2], m[1])
  me.tell 'Password changed.'
end

def cmd_idalias(me, cmd, args)
  args.strip!
  if args == 'list'
    me.tell 'ID Alias List:'
    aliases = me['_idaliases']
    if aliases.nil?
      me.tell 'No aliases.'
    else
      count = 0
      aliases.each {|key, value|
        me.tell "  $#{key}: #{database.id_to_object(value)}"
        count += 1
      }
      me.tell "#{count} aliases."
    end
    return
  end
  if args.nil? or args.empty? or not args.include? '='
    me.tell "Usage: #{cmd} <id alias>=<object>"
    me.tell "   or: #{cmd} list"
    return
  end
  idalias, target = args.strip.split('=')
  target_obj = me.text_to_object target
  raise UserError, "Could not find object '#{dest}'." unless target_obj
  assert_perm_to_link_to(me, target_obj, 'You cannot link to that, therefore you cannot create an id alias to it.')
  me["_idaliases/#{idalias}"] = target_obj.id_s
  me.tell "Id alias '#{idalias}' created for #{target_obj}."
end

def cmd_take(me, cmd, args)
  obj_name = args.strip
  obj = me.text_to_object obj_name
  raise UserError, 'I don\'t see that here.' unless obj
  raise UserError, 'You are already carrying that.' if obj.where == me
  # TODO raise UserError, 'You can\'t take that.' unless obj.locked?(me)

  raise UserError, "You can't reach that from here." unless obj.where == me.where

  # OK to take.
  # FIXME: Check permissions!
  obj.where = me
  me.tell "#{obj} taken."
  me.tell_others_in_room "#{me.name} picks up #{obj.name}."
end

def cmd_drop(me, cmd, args)
  obj_name = args.strip
  obj = me.text_to_object obj_name
  raise UserError, "You aren't carrying anything like that." unless obj and obj.where == me
  raise UserError, 'Permission denied.  Cannot drop dark objects in rooms you don\'t own.' unless me.wizard? or me.where.owner == me or obj.has_flag?(:dark) == false
  obj.where = me.where
  me.tell "Dropped."
  me.tell_others_in_room "#{me.name} drops #{obj.name}."
end

def cmd_inventory(me, cmd, args)
  me.tell "You are carrying:"
  count = 0
  me.visible_objects(me).each {|obj|
    me.tell "  #{obj}"
    count += 1
  }
  me.tell "#{count} objects."
end

def cmd_tele(me, cmd, args)
  m = args.match("(#{LGLOBJ})=(#{LGLOBJ})")
  raise UserError, "Syntax: #{cmd} <object to teleport>=<new location>" unless m
  
  move_this = me.text_to_object m[1]
  raise UserError, "Could not find object '#{m[1]}'." unless move_this
  assert_perm_to_modify(me, move_this)

  to_here = me.text_to_object m[2]
  raise UserError, "Could not find object '#{m[2]}'." unless to_here
  assert_perm_to_link_to(me, to_here)
  raise UserError, 'Permission denied.  Cannot move dark objects into rooms you don\'t own.' unless me.wizard? or to_here.owner == me or obj.has_flag?(:dark) == false
  
  if move_this.player?
    move_this.tell_others_in_room "#{move_this.name} has left."
    move_this.tell "You have been teleported!" if move_this != me
  end
  move_this.where = to_here
  me.tell "#{move_this.name} has been teleported to #{to_here.name}." if move_this != me
  if move_this.player?
    move_this.look if move_this.online?
    move_this.tell_others_in_room "#{move_this.name} has arrived."
  end
end

add_command '@name', :cmd_name
add_command '@desc', :cmd_desc
add_command '@link', :cmd_link
add_command 'prop', :cmd_prop
add_command '@chown', :cmd_chown
add_command 'gohome', :cmd_gohome
add_command '@action', :cmd_action
add_command '@open', :cmd_open
add_command '@dig', :cmd_dig
add_command '@create', :cmd_create
add_command '@delete', :cmd_delete
add_command '@idalias', :cmd_idalias
add_command 'take', :cmd_take
add_command 'drop', :cmd_drop
add_command 'inv', :cmd_inventory
add_command '@tele', :cmd_tele

desc 'Set/clear flags on objects.'
help 'Usage: @set <object>=[!]<flag>'
command '@set' do |me,cmd,args|
  m = args.match("^(#{LGLOBJ})\s*=\s*(.*)$")
  raise UserError, 'Syntax error.' unless m
  obj = me.text_to_object m[1]
  raise UserError, 'I don\'t see that here.' unless obj
  part2 = m[2]
  if m = part2.match(/^(\!?)([A-Za-z0-9]+)$/) # Flag
    set_on = (m[1] != '!')
    flag = m[2].to_sym
    raise UserError, 'Unknown flag.' unless ALL_FLAGS.include? flag
    raise UserError, 'Permission denied.' unless me.can_set_flag?(obj, flag)
    obj.set_flag(flag, set_on)
    un = set_on ? '' : 'un'
    me.tell "Flag #{flag} #{un}set on #{obj}."
  elsif m = part2.match(/^(\S+):(.*)$/)
    raise UserError, "Permission denied." unless obj.set_prop(me, m[1], m[2])
    me.tell "Property set."
  else
    me.tell "Syntax error."
  end
end

desc 'Examines an object.'
help 'Usage: examine <object>'
command 'examine;ex' do |me,cmd,args|
  if m = args.match("^(#{LGLOBJ})\s*=\s*(.*)$")
    target = me.text_to_object m[1]
    raise UserError, "I don't see that here." unless target
    assert_perm_to_modify(me, target)
    cmd_prop_print(me, target, m[2])
  else
    args = 'here' if args.empty?
    m = args.match("^(#{LGLOBJ})$")
    raise UserError, 'Syntax error.' unless m
    obj = me.text_to_object m[1]
    raise UserError, 'I don\'t see that here.' unless obj
    raise UserError, 'Permission denied.' unless me.can_modify? obj
    me.tell "Name: #{obj.look_name(me)}"
    me.tell "Flags: #{obj.flags.join(', ')}"
    me.tell "Desc: #{obj.desc.nil? ? 'unset' : obj.desc[0..60]+(obj.desc.length > 60 ? '...' : '')}"
    me.tell "Owner: #{obj.owner ? obj.owner.look_name(me) : 'unset'}"
    me.tell "Where: #{obj.where ? obj.where.look_name(me) : 'unset'}"
    me.tell "Link:  #{obj.link ? obj.link.look_name(me) : 'unset'}"
    me.tell "Last connected:    #{Time.at(obj['%/last_connect'].to_i)}" unless obj['%/last_connect'].nil?
    me.tell "Last disconnected: #{Time.at(obj['%/last_disconnect'].to_i)}" unless obj['%/last_connect'].nil?
    me.tell 'Contents:' unless obj.contents.empty?
    obj.contents.each {|inv|
      me.tell " #{inv.look_name(me)}"
    }
  end
end

desc 'Provides help information for commands.'
help 'Usage: help <command>'
command 'help;?' do |me,cmd,args|
  args.strip!
  if args.empty?
    # List all commands.
    me.tell "RubyMUCK Command Help"
    me.tell '-'*70
    max_name_length = Connection.commands.values.map {|c| c[:names][0].length }.max
    Connection.commands.values.uniq.sort {|x,y| x[:names][0] <=> y[:names][0]}.each {|cmd|
      next unless cmd[:allow].call(me) unless cmd[:allow].nil?
      me.tell "%-#{max_name_length}s %s" % [cmd[:names][0], cmd[:desc] || '']
    }
  else
    raise UserError, "No help available for #{args}." unless Connection.commands.has_key? args
    help_text = Connection.commands[args][:help]
    if help_text
      help_text = help_text.gsub('CMD', args)
    end
    me.tell help_text || "No help available for #{args}."
  end
end

desc 'Evaluate a line of interpreted language.'
command '@eval' do |me,cmd,args|
  parser = Parser.create(me, me)
  me.tell 'Result: '+(parser.parse(args).to_s)
end

# command 'interview' do |me,cmd,args|
#   me.tell 'Starting the interview!'
#   answers = me.interview [[:name, 'What is your name?'], [:color, 'What is your favorite color?']]
#   me.tell "Your name is #{answers[:name]} and your favorite color is #{answers[:color]}."
# end

desc 'Multiline property editor.'
help 'CMD <object>=<property>'
command 'vi' do |me,cmd,args|
  
end
