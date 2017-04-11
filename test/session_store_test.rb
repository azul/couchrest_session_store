require 'test_helper'
require 'session_store_tester'
require 'couch_tester'

class SessionStoreTest < MiniTest::Test
  # by default we create a session that does not expire
  # call fresh_session or expired_session to set an expiry.
  def setup
    @store = SessionStoreTester.new
    @couch = CouchTester.new
    @sid, @session = get_session
    @session[:key] = 'stub'
    set_session
  end

  def teardown
    @store.destroy_session sid
  end

  def test_session_initialization
    sid, session = get_session
    assert sid
    assert_equal({}, session)
  end

  def test_normal_session_flow
    assert_equal [sid, session], get_session(sid)
  end

  def test_updating_session
    session[:bla] = 'blub'
    set_session
    assert_equal [sid, session], get_session(sid)
  end

  def test_prevent_access_to_design_docs
    design_id = '_design/bla'
    set_session design_id, views: 'my hacked view'
    assert_nil couch.get(design_id)
  end

  def test_unmarshalled_session_flow
    set_session sid, session, marshal_data: false
    got_sid, got_session = get_session sid
    assert_equal sid, got_sid
    assert_equal session[:key], got_session['key']
  end

  def test_unmarshalled_data
    set_session sid, session, marshal_data: false
    data = couch.get(sid)['data']
    assert_equal session[:key], data['key']
  end

  def test_logout_in_between
    store.destroy_session sid
    _other_sid, other_session = get_session sid
    assert_equal({}, other_session)
  end

  def test_can_logout_twice
    store.destroy_session sid
    store.destroy_session sid
    _other_sid, other_session = get_session
    assert_equal({}, other_session)
  end

  def test_stored_and_not_expired_yet
    set_session sid, session, expire_after: 300
    doc = couch.get sid
    expires_in = Time.parse(doc[:expires]) - Time.now
    assert expires_in > 0, 'Expiry should be in the future'
    assert expires_in <= 300, 'Should expire after 300 seconds - not more'
  end

  def test_stored_but_expired
    expired_session
    other_sid, other_session = get_session sid
    assert_equal({}, other_session, 'session should have expired')
    assert other_sid != sid
  end

  def test_store_without_expiry
    assert_nil couch.get(sid)['expires']
    assert_equal [sid, session], get_session(sid)
  end

  def test_cleanup_sessions
    store.cleanup [{ 'id' => sid }]
    assert_nil couch.get(sid)
  end

  def test_keep_during_cleanup_of_others
    other_sid, other_session = get_session
    set_session other_sid, other_session
    store.cleanup [{ 'id' => other_sid }]
    assert_equal [sid, session], get_session(sid)
  end

  attr_reader :sid, :session, :store, :couch
  def get_session(sid = nil)
    store.get_session sid
  end

  def set_session(id = sid, record = session, options = {})
    store.set_session id, record, options
  end

  def fresh_session
    expire sid, Time.now + 10.minutes
  end

  def expired_session
    expire sid, Time.now - 10.minutes
  end

  def expire(sid, expiry)
    couch.update sid, 'expires' => expiry.utc.iso8601
  end
end
