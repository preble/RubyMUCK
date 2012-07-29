desc 'Force a database save.'
allow { |me| me.wizard? }
command '@save!' do |me,cmd,args|
  $server.log "Database save initiated by #{me}."
  me.tell 'Saving...'
  $server.save
  me.tell 'Done.'
end

desc 'Boot a player offline.'
help 'CMD <player>'
allow {|me| me.wizard? }
command '@boot' do |me,cmd,args|
  target = database.player_by_name(args)
  raise UserError, "#{args} is offline." unless target.online?
  target.io = nil
  me.tell "Booted #{target}."
end

desc 'Load a file into the Ruby interpreter.'
allow { |me| me.has_flag? :god }
command '@load' do |me,cmd,args|
  $server.log "#{me} loading #{args}..."
  raise UserError, "File #{args} not found." unless File.exists? args
  begin
    # TODO: Add more security to this!
    result = load args
    me.tell 'Loaded: '+result.inspect
  rescue => detail
    trace = detail.backtrace[0..5].join("\n  ")
    me.tell "Error while loading #{args}: #{detail}\n  #{trace}"
  end
end

desc 'Reload modules.'
allow { |me| me.wizard? }
command '@reload' do |me,cmd,args|
  $server.log "#{me} reloading..."
  Connection.load_modules
  me.tell 'Modules reloaded.'
end


desc 'Create a new player.'
help 'CMD <name>=<password>'
allow { |me| me.wizard? }
command '@createplayer' do |me, cmd, args|
  raise UserError, "Usage: #{cmd} <name>=<password>" if args.nil? or args.empty? or not args.include? '='
  args.strip!
  m = args.match '('+LGLOBJ+')=(\w+)'
  raise UserError, 'Name or password may have invalid characters.' unless m

  raise UserError, 'That name is already in use.' if database.players.has_key?(m[1].downcase)

  player = Player.new(m[1])
  player.password = m[2]
  player.owner = player
  player.where = database.id_to_object(NEW_PLAYER_ROOM)
  player.link = player.where
  me.tell "Player #{player} created."
end
