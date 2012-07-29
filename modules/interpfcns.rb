#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-16.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
#
#  Interpreted function definitions.
#

# log(message)
rmi_fcn :log do |parser,args|
  puts 'Log: '+args.join
  ''
end

# tell(object, message)
rmi_fcn :tell do |parser,args|
  tellee = parser.arg_to_obj args[0]
  raise "tell: Invalid target." unless tellee
  tellee.tell args[1]
  ''
end

# name(object)
rmi_fcn :name do |parser,args|
  obj = parser.arg_to_obj args[0]
  raise "name: Invalid object: #{args[0]}" unless obj
  obj.name
end

# where(object)
rmi_fcn :where do |parser,args|
  obj = parser.arg_to_obj args[0]
  raise "where: Invalid object: #{args[0]}" unless obj
  obj.where
end

# prop(object, path)
rmi_fcn :prop do |parser,args|
  obj = parser.arg_to_obj args[0]
  raise "prop: Invalid object." unless obj
  obj.get_prop(parser.var_me, args[1]) || ''
end

# setprop(object, path, value)
rmi_fcn :setprop do |parser,args|
  obj = parser.arg_to_obj args[0]
  raise "setprop: Invalid object." unless obj
  obj.set_prop(parser.var_me, args[1], args[2])
  obj.get_prop(parser.var_me, args[1]) || '' # Return the new value.
end
