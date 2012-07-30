require "test/unit"

require_relative "../lib/database"
require_relative "../lib/object"

include RubyMUCK

class TestDatabase < Test::Unit::TestCase
  def test_formats
    formats = [:yaml, :oldyaml, :dump, :olddump]
    
    # Build up the database
    database.clear
    classes = [Thing, Action, Action, Room]
    100.times do |x|
      klass = classes[rand * classes.length]
      klass.new("#{klass} #{x}", x+1)
    end
    
    db_length = database.objects.length
    
    formats.each do |format|
      filename = "rubymuck_unittesting.db"
      
      # Write the database to disk and reload.
      database.save filename, format
      
      database.clear
      assert_equal(0, database.objects.length)
      
      database.load filename, format
      
      assert_equal(db_length, database.objects.length)
      database.objects.each do |id,obj|
        assert_equal(id, obj.id)
        assert_equal("#{obj.class} #{id-1}", obj.name)
      end
      # TODO: Add more checks!
      
      File.delete filename
    end
  end
end