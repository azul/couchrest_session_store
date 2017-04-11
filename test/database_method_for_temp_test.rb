require 'test_helper'
require 'couchrest_model'
require 'couchrest/model/database_method'

#
# A test scenario for database_method in which some user accounts
# are stored in a seperate temporary database (so that the test
# accounts don't bloat the normal database).
#
class DatabaseMethodForTempTest < MiniTest::Test
  class User < CouchRest::Model::Base
    include CouchRest::Model::DatabaseMethod

    use_database_method :db_name
    property :login, String
    before_save :create_db

    class << self
      def get(id, db = database)
        super(id, db) ||
          super(id, choose_database('test-user'))
      end
      alias find get

      def db_name(login = nil)
        if !login.nil? && login =~ /test-user/
          'tmp_users'
        else
          'users'
        end
      end
    end

    protected

    def db_name
      self.class.db_name(login)
    end

    def create_db
      database! unless database_exists?(db_name)
    end
  end

  def setup
    @user = User.new(login: 'test-user-1')
    user.save
  end

  def teardown
    @user.destroy
  end

  def test_tmp_user_retrival
    assert_equal user, User.find(user.id),
      'should find temp user through User.find'
  end

  def test_tmp_user_db
    tmp_db = User.server.database('couchrest_tmp_users')
    tmp_record = tmp_db.get(user.id)
    assert_equal user.login, tmp_record[:login]
  end

  def test_tmp_user_not_in_normal_db
    assert_nil User.server.database('couchrest_users').get(user.id)
  end

  attr_reader :user
end
