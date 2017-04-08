require 'test_helper'

class SessionStoreFinderTest < MiniTest::Test
  def setup
    @store = CouchRest::Session::Store.new(nil, {})
    @couch = CouchTester.new
    @no_expiry = seed_session
    @fresh = seed_session expires: (Time.now + 10.minutes)
    @expired = seed_session expires: (Time.now - 10.minutes)
  end

  def teardown
    sessions.each do |sid|
      store.send :destroy_session, env, sid, drop: true
    end
  end

  def test_find_expired_sessions
    expired_ids = store.expired.map { |row| row['id'] }
    assert_includes expired_ids, expired
    refute_includes expired_ids, fresh
    refute_includes expired_ids, no_expiry
  end

  def test_find_no_expiry_sessions
    no_expiry_ids = store.never_expiring.map { |row| row['id'] }
    assert_includes no_expiry_ids, no_expiry
    refute_includes no_expiry_ids, fresh
    refute_includes no_expiry_ids, expired
  end

  attr_reader :fresh, :expired, :no_expiry, :store, :couch

  def sessions
    [fresh, expired, no_expiry]
  end

  def seed_session(expires: nil)
    sid, session = store.send :get_session, env, nil
    store.send :set_session, env, sid, session, {}
    couch.update sid, 'expires' => expires.utc.iso8601 if expires
    sid
  end

  def env
    {}
  end
end
