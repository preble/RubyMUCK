require "test/unit"

require_relative '../lib/object'
require_relative '../lib/interpreted'
require_relative '../modules/interpfcns'

include RubyMUCK

class TestInterpreted < Test::Unit::TestCase
  def setup
    @player = Player.new('Player1')
    @room = Room.new('Room1')
    @room.owner = Player.new('Player2')
    @player.where = @room
    @player.owner = @player
    @parser = Parser.create(@player, @player)
  end
  def test_name
    assert_equal(@player.name, @parser.parse('me.name'))
  end
  def test_where
    assert_equal(@player.where, @parser.parse('me.where'))
  end
  def test_prop
    @player['test'] = 'howdy'
    assert_equal(@player['test'], @parser.parse('me.prop("test")'))
    assert_equal('new_howdy', @parser.parse('me.setprop("test", "new_howdy")'))
    assert_equal('', @parser.parse('me.prop("%/name")')) # empty because permission denied
    assert_equal('', @parser.parse('me.setprop("%/name","Bang!")')) # empty because permission denied
    assert_equal('', @parser.parse('here.setprop("graffiti", "value")'))
    @room['prop'] = 'value'
    assert_equal('value', @parser.parse('me.where.prop("prop")')) # We can access props that don't start with an underscore.
    assert_equal('', @parser.parse('here.prop("_protected")')) # We can't access props that start with an underscore (on objects we don't own).
  end
  def test_strings
    assert_equal('Howdy', @parser.parse('"How"+"dy"'))
    assert_equal('Player1 says hi', @parser.parse('me.name+" says hi"'))
    assert_equal('My name is Player1', @parser.parse('"My name is "+me.name'))
    #assert_equal('My name is Player1', @parser.parse('"My name is "+carlos')) # Should throw an error as carlos is not defined?
  end
end