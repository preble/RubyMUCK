require "test/unit"

require "lib/object"

include RubyMUCK

class TestPlayer < Test::Unit::TestCase
  def setup
    database.clear
    @p1 = Player.new('Player 1')
    @obj1 = Thing.new('Object1')
    @obj2 = Thing.new('Object2')
    @room = Room.new('Room')
    @p1.where = @room
    @obj1.where = @room
    @obj2.where = @room
  end
  def test_player
    assert_not_nil(@p1)
    assert_equal(1, @p1.id)
    assert_equal('Player 1', @p1.name)
    assert(@p1.online? == false, "p1 should not be online")
    assert_not_nil(@p1.text_to_object('Object1'))
    assert_not_nil(@p1.text_to_object('obJect1'))
    assert_not_nil(@p1.text_to_object('#1'))
    assert_nil(@p1.text_to_object('obj'))
    assert_equal(@p1, @p1.text_to_object('me'))
    assert_equal(@room, @p1.text_to_object('here'))
  end
  
  def test_wizard
    assert(@p1.wizard? == false, "p1 should not be a wizard")
    @p1.set_flag(:wizard, true)
    assert(@p1.wizard?, "p1 should be a wizard")
    @p1.set_flag(:god, true)
    assert(@p1.wizard?, "p1 should still be a wizard")
    @p1.set_flag(:wizard, false)
    assert(@p1.wizard?, "p1 even should still be a wizard")
    @p1.set_flag(:god, true)
    assert(@p1.wizard?, "p1 should no longer be a wizard")
  end
end