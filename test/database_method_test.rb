require 'test_helper'
require "byebug"

class DatabaseMethodTest < MiniTest::Test

  #
  # A test scenario for database_method in which some user accounts
  # are stored in a seperate temporary database (so that the test
  # accounts don't bloat the normal database).
  #

  class User < CouchRest::Model::Base
    include CouchRest::Model::DatabaseMethod

    use_database_method :db_name
    property :login, String
    before_save :create_db

    class << self
      def get(id, db = database)
        result = super(id, db)
        if result.nil?
          return super(id, choose_database('test-user'))
        else
          return result
        end
      end
      alias :find :get
    end

    protected

    def self.db_name(login = nil)
      if !login.nil? && login =~ /test-user/
        'tmp_users'
      else
        'users'
      end
    end

    def db_name
      self.class.db_name(self.login)
    end

    def create_db
      unless database_exists?(db_name)
        self.database!
      end
    end

  end

  def test_tmp_user_db
    user1 = User.new({:login => 'test-user-1'})
    assert user1.save
    assert User.find(user1.id), 'should find user in tmp_users'
    assert_equal user1.login, User.find(user1.id).login
    assert_equal 'test-user-1', User.server.database('couchrest_tmp_users').get(user1.id)['login']
    assert_nil User.server.database('couchrest_users').get(user1.id)
  end

end
