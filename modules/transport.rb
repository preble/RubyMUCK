#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-16.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
#
#  Transportation-related commands.
#

desc 'Summons a player to your location.'
help 'CMD <player>'
command 'summon;join;desummon' do |me,cmd,args|
  target = database.player_by_name(args)
  raise UserError, ">> Could not find a player by that name." unless target
  if cmd == 'summon'
    raise UserError, ">> #{target.name} is asleep." unless target.online?
    prefix = "_summon/#{target.name}"
    me["#{prefix}/expiration"] = (Time.now + 30*60).to_i.to_s # Expires in 30 minutes.
    target.tell ">> #{me.name} has summoned you.\n>>Type 'join #{me.name}' in the next 30 minutes to join them."
    me.tell ">> You have summoned #{target.name}.  This invitation will expire in 30 minutes."
    me.tell ">> You can cancel your invitation with 'desummon #{target.name}'."
  elsif cmd == 'join'
    raise UserError, ">> #{target.name} is asleep." unless target.online?
    prefix = "_summon/#{me.name}"
    raise UserError, ">> You don't have an invitation from that player." unless exp = target["#{prefix}/expiration"]
    exp = Time.at(exp.to_i)
    if Time.now > exp
      target[prefix] = nil
      raise UserError, ">> That invitation has expired."
    end
    # We have passed all of the hurdles.  Execute the summons.
    me.tell ">> You accept #{target.name}'s summons."
    me.tell_others_in_room "#{me.name} fades out of existence."
    me.where = target.where
    me.look
    me.tell_others_in_room "#{me.name} fades into existence next to #{target.name}."
    target[prefix] = nil # Clear out the invitation.
  elsif cmd == 'desummon'
    prefix = "_summon/#{target.name}"
    raise UserError, ">> You have not summoned that player." if me[prefix].nil?
    me[prefix] = nil
    target.tell ">> #{me.name} has cancelled their summon invitation."
    me.tell '>> Invitation cancelled.'
  else
    raise UserError, ">> Unknown command?"
  end
end

desc 'Teleport to a public location.'
help 'CMD [location]'
command 'tport;t' do |me,cmd,args|
  one = database.id_to_object 1
  raise UserError, '>> Unable to find teleport configuration object.' unless one
  data = one['_tport']
  raise UserError, '>> No teleports have been configured.' unless data and data.has_key? 'dests'
  dests = data['dests']
  
  if args.empty?
    me.tell '>> Teleport Destinations'
    max_key_length = dests.keys.map{|k| k.length}.max
    dests.each do |key, value|
      me.tell "  %-#{max_key_length}s: %s" % [key, value['desc'] || '']
    end
    me.tell ">> '#{cmd} <name>' to teleport"
  elsif m = args.match(/^#set (\w+)\s*=\s*(.*)/)
    raise UserError, 'Permission denied.' unless me.wizard?
    name = m[1]; desc = m[2]
    if desc.nil? or desc.empty?
      dests.delete name
      me.tell '>> Destination cleared.'
    else
      dests[name] = {'desc'=>desc, 'link'=>me.where.id_s}
      me.tell '>> Destination set.'
    end
  else
    raise UserError, ">> Unknown destination, '#{args}'.  '#{cmd}' lists valid destinations." unless dests.has_key? args
    dest = dests[args]
    raise UserError, ">> Teleport desination improperly configured." unless dest.has_key? 'link'
    raise UserError, ">> Unable to find destination." unless dest_obj = database.id_to_object(dest['link'])
    me.tell ">> You teleport to #{args}..."
    me.tell_others_in_room "#{me.name} fades out of existence."
    me.where = dest_obj
    me.look
    me.tell_others_in_room "#{me.name} fades into existence."
  end
end

