#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-16.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
#
require 'monitor'
require 'thread'
require_relative 'rdparser'

module RubyMUCK
  # Uses the RDParser to implement the 'RubyMUCK Interpreted Language'.
  #
  # Examples:
  #
  #   log("Player "+me.name+" is in "+me.where.name)
  #
  #   me.tell("Hello!")
  #
  class Parser < RDParser
    @@functions = {}
    attr_accessor :var_me, :var_this
    def arg_to_obj(arg)
      return arg if arg.is_a? Thing
      case arg
      when 'me'
        self.var_me
      when 'this'
        self.var_this
      when 'here'
        self.var_me.where
      else
        nil
      end
    end
    def do_call(fcn, args)
      out = ''
      fcn_sym = fcn.downcase.to_sym
      if @@functions.has_key? fcn_sym
        out = @@functions[fcn_sym].call(self, args)
      else
        raise "Unknown function: #{fcn}"
      end
      out
    end
    def Parser.functions
      @@functions
    end
    def Parser.create(_me=nil, _this=nil)
      parser = Parser.new do
        token(/\s+/)
        token(/\d+/) {|m| m.to_i }
        token(/"([^"\\]*(\\.[^"\\]*)*)"/) {|m| m[1..-2].gsub('\"','"') } # Double-quoted string.  Trim off the quotes.
        token(/[A-Za-z][A-Za-z0-9_]+/) {|m| m}
        token(/./) {|m| m }

        start :expr do
          match(:expr, '+', :term) {|a, _, b| a + b }
          match(:expr, '-', :term) {|a, _, b| a - b }
          match(:expr, ';', :call) {|a, _, b| a + b }
          match(:term)
        end

        rule :term do
          match(:term, '*', :call) {|a, _, b| a * b }
          match(:term, '/', :call) {|a, _, b| a / b }
          match(:call)
        end

        rule :call do
          #match(:call, '.', :atom, '.', :atom, '(', :expr, ')') {|a, _, b, _, c, _, d, _| do_call(c, [do_call(b, [a]), d]) }
          #match(:call, '.', :atom, '.', :atom) {|a, _, b, _, c| do_call(c, [do_call(b, [a])]) }
          match(:call, '.', String, '(', :expr, ',', :expr, ')') {|o, _, f, _, a0, _, a1, _| do_call(f, [o, a0, a1]) }
          match(:call, '.', String, '(', :expr, ')') {|o, _, f, _, a0, _| do_call(f, [o, a0]) }
          match(:call, '.', String) {|o, _, f| do_call(f, [o]) }
          match(:fcncall)
        end

        rule :fcncall do
          match(:fcncall, '(', ')') {|a, _, _| do_call(a, []) }
          match(:fcncall, '(', :expr, ')') {|a, _, b| do_call(a, [b]) }
          match(:fcncall, '(', :expr, ',', :expr, ')') {|a, _, b, _, c| do_call(a, [b,c]) }
          match(:fcncall, '(', :expr, ',', :expr, ',', :expr, ')') {|a, _, b, _, c, _, d| do_call(a, [b,c,d]) }
          match(:atom)
        end

        rule :atom do
          match(Integer)
          match(String)
          match('(', :expr, ')') {|_, a, _| a }
        end
      end
      parser.var_me = _me
      parser.var_this = _this
      parser
    end
    
    # Class variable setup.
    @@pool = []
    @@pool.extend(MonitorMixin)
    @@pool_released = @@pool.new_cond
    10.times { @@pool.push Parser.create } # Create a pool of 10 parsers.
    
    # Returns a Parser instance.  #release must be called on the instance to return it to the pool!
    def Parser.instance
      @@pool.synchronize do
        while @@pool.empty?
          @@pool_released.wait
        end
        inst = @@pool.pop
      end
    end
    def release
      @@pool.synchronize do
        @@pool.push self
        @@pool_released.signal
      end
    end
  end

end

# Use to define interpreter functions.
#
#  interpfcn :fcn_name do |parser, args|
#    ...
#  end
def rmi_fcn(name, &block)
  RubyMUCK::Parser.functions[name] = block
end
