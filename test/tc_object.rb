require "test/unit"

require_relative "../lib/object"

include RubyMUCK

class TestObject < Test::Unit::TestCase
  def setup
    database.clear
  end
  def test_object_creation
    obj = Thing.new('Test Object')
    assert_not_nil(obj)
    assert_equal(1, obj.id)
    assert_equal('Test Object', obj.name)
    assert_nil(obj.where)
    assert_nil(obj.owner)
    assert_nil(obj.link)
    assert(obj.contents.empty?, "Expected to be empty.")
    
    obj.name = 'New Name'
    assert_equal('New Name', obj.name)
    assert_equal(obj, database.id_to_object(1))
    assert_equal(obj, database.id_to_object('#1'))
    
    obj2 = Thing.new('Test Object 2')
    assert_not_nil(obj2)
    assert_equal(2, obj2.id)
    assert_equal(obj2, database.id_to_object(2))
    assert_nil(obj.where)
    
    obj2.where = obj
    assert_equal(obj, obj2.where)
    assert_equal(obj2, obj.contents.first)
    
    assert_raise(RuntimeError) { Thing.new('Should Fail because id=0 is not allowed', 0) }
    assert_raise(RuntimeError) { Thing.new('Should Fail because id=1 is already in use', 1) }
  end
  
  def test_flags
    obj = Thing.new('Flag Test Object')
    ALL_FLAGS.each {|flag|
      assert(!obj.has_flag?(flag), "Obj should not have any flags set.")
    }
    obj.set_flag(ALL_FLAGS.first, true)
    ALL_FLAGS.each {|flag|
      if flag != ALL_FLAGS.first
        assert(!obj.has_flag?(flag), "Flag #{flag} should not be set.")
      else
        assert(obj.has_flag?(flag), "Flag #{flag} should be set.")
      end
    }
    obj.set_flag(ALL_FLAGS.first, false)
    ALL_FLAGS.each {|flag|
      assert(!obj.has_flag?(flag), "Obj should not have any flags set.")
    }
    
  end
end