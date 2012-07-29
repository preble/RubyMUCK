#  RubyMUCK - http://incompletelabs.com/rubymuck/
#  Created by Adam Preble on 2007-10-16.
#  Provided under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
#    http://creativecommons.org/licenses/by-nc-sa/3.0/
module RubyMUCK
  class Console
    def run
      puts "RubyMUCK Console: 'exit' to save & exit, 'exit!' to exit immediately."
      loop do
        print "RM>> "
        $stdout.flush
        input = $stdin.gets.chomp
        begin
          if input == 'exit'
            benchmarked_save
            break
          elsif input == 'exit!'
            break
          elsif input == 'save'
            $server.save
            next
          end
          unless input.empty?
            puts  "=> " + eval( input ).inspect
          end
        rescue => detail
          puts "Error in console input: #{detail}"
          puts detail.backtrace[0..5].join("\n")
        end
      end
    end
  end
end
