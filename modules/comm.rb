#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-16.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
#
#  Communications-related commands.
#

desc 'Say something to everybody in the room.  Shortcut: \'"\'.'
help 'say <message>, "<message>'
command 'say' do |me,cmd,text|
  me.tell_others_in_room(wrap_indent_text(me.name+" says, \""+text+"\""))
  me.tell wrap_indent_text("You say, \"#{text}\"")
end
add_command 'say', :cmd_say

def eval_pose(me, text)
  text.strip!
  case text[0]
  when ?', ?,
    otell = me.name+text
  else
    otell = me.name+" "+text
  end
  otell
end

desc 'Perform a text-described action.  Shortcut: \':\'.'
help 'pose <action>, :<action>'
command 'pose' do |me,cmd,text|
  otell = wrap_indent_text(eval_pose(me, text))
  me.tell_others_in_room otell
  me.tell otell
end

desc 'Send a message to a player in another room.'
help 'Usage: page <player>=[:]<message>'
command 'page;p' do |me,cmd,args|
  args.strip!
  m = args.match /^(.*?)\s*=\s*(.*)$/
  raise UserError, "Usage: #{cmd} <player>=[:]<message>" if args.empty? or m.nil?
  
  target = m[1]
  message = m[2]
  
  target = me['_page/last_to'] if target.empty? && me['_page/last_to']
  
  target.strip!
  message.strip!
  target_obj = database.player_by_name(target)
  raise UserError, "Could not find a player named #{target}." unless target_obj
  raise UserError, "#{target_obj.name} is offline." unless target_obj.online?
  
  me['_page/last_to'] = target_obj.name
  
  if message.empty?
    target_obj.tell "#{me.name} pages you."
    me.tell "You page #{target_obj.name}."
  else
    if message[0] == ?:
      pose = eval_pose me, message[1..-1]
      target_obj.tell "In a page-pose to you, #{pose}"
      me.tell "You page-pose #{target_obj.name}, #{pose}"
    else
      target_obj.tell "#{me.name} pages, \"#{message}\""
      me.tell "You page #{target_obj.name}, \"#{message}\""  
    end
  end
end

desc 'Send a message to a player in this room.'
help 'Usage: CMD <player>=[:]<message>'
command 'whisper;wh' do |me,cmd,args|
  args.strip!
  m = args.match /^(.*?)\s*=\s*(.*)$/
  raise UserError, "Usage: #{cmd} <player>=[:]<message>" if args.empty? or m.nil?

  target = m[1]
  message = m[2]
  
  target = me['_whisper/last_to'] if target.empty? && me['_whisper/last_to']
  
  target.strip!
  message.strip!
  target_obj = me.text_to_object target
  raise UserError, "Could not find a player named #{target}." unless target_obj and target_obj.player?
  raise UserError, "#{target_obj.name} is not here!" unless target_obj.where == me.where
  raise UserError, "#{target_obj.name} is offline." unless target_obj.online?
  
  me['_whisper/last_to'] = target_obj.name
  
  if message.empty?
    target_obj.tell "#{me.name} whisper-pages you."
    me.tell "You whisper-page #{target_obj.name}."
  else
    if message[0] == ?:
      pose = eval_pose me, message[1..-1]
      target_obj.tell "In a whisper-pose to you, #{pose}"
      me.tell "You whisper-pose #{target_obj.name}, #{pose}"
    else
      target_obj.tell "#{me.name} whispers, \"#{message}\""
      me.tell "You whisper to #{target_obj.name}, \"#{message}\""  
    end
  end
end
