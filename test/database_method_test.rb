require 'test_helper'
require 'byebug'

class DatabaseMethodTest < MiniTest::Test
  class TestModel < CouchRest::Model::Base
    include CouchRest::Model::DatabaseMethod

    use_database_method :db_name
    property :dbname, String
    property :confirm, String

    def db_name
      "test_db_#{self[:dbname]}"
    end
  end

  def test_instance_method_db_path
    with_doc_and_db dbname: 'one' do |_doc, db|
      assert_equal '/couchrest_test_db_one', db.root.path
    end
  end

  def test_instance_method_doc_retrieval
    with_doc_and_db dbname: 'one' do |doc, db|
      doc.save
      doc.update_attributes(confirm: 'yep')
      retrieved = CouchRest.get([db.root, doc.id].join('/'))
      assert_equal 'yep', retrieved['confirm']
    end
  end

  def test_switch_db
    with_doc_and_db dbname: 'red', confirm: 'rose' do |red, db|
      clone_to_db 'blue', red do |blue|
        blue_url = [db.root.to_s.sub('red', 'blue'), blue.id].join('/')
        blue_copy = CouchRest.get blue_url
        assert_equal 'rose', blue_copy['confirm']
      end
    end
  end

  def clone_to_db(dbname, doc)
    doc.clone.tap do |clone|
      begin
      clone.dbname = dbname
      clone.database!
      clone.save!
      yield clone
      ensure
        clone.database.delete!
      end
    end
  end

  def with_doc_and_db(fields = {})
    TestModel.new(fields).tap do |doc|
      begin
        doc.database.create!
        yield doc, doc.database
      ensure
        doc.database.delete!
      end
    end
  end

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

  def test_tmp_user_retrival
    with_tmp_user do |user1|
      assert_equal user1, User.find(user1.id),
        'should find temp user through User.find'
    end
  end

  def test_tmp_user_db
    with_tmp_user do |user1|
      tmp_db = User.server.database('couchrest_tmp_users')
      tmp_record = tmp_db.get(user1.id)
      assert_equal user1.login, tmp_record[:login]
    end
  end

  def test_tmp_user_not_in_normal_db
    with_tmp_user do |user1|
      assert_nil User.server.database('couchrest_users').get(user1.id)
    end
  end

  def with_tmp_user
    user = User.new(login: 'test-user-1')
    user.save
    yield user
  ensure
    user.destroy
  end
end
