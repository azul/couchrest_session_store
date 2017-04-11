require 'test_helper'
require 'couchrest_model'
require 'couchrest/model/database_method'

class DatabaseInstanceMethodTest < MiniTest::Test
  class TestModel < CouchRest::Model::Base
    include CouchRest::Model::DatabaseMethod

    use_database_method :db_name
    property :dbname, String
    property :confirm, String

    def db_name
      "test_db_#{self[:dbname]}"
    end
  end

  def setup
    @doc = TestModel.new dbname: 'red'
    db.create!
  end

  def teardown
    db.delete!
  end

  def test_root_path
    assert_equal '/couchrest_test_db_red', root.path
  end

  def test_doc_retrieval
    doc.save
    doc.update_attributes confirm: 'yep'
    retrieved = CouchRest.get([db.root, doc.id].join('/'))
    assert_equal 'yep', retrieved['confirm']
  end

  def test_switch_db
    doc.update_attributes confirm: 'rose'
    clone_to_db 'blue' do |blue|
      blue_url = [root.to_s.sub('red', 'blue'), blue.id].join('/')
      blue_copy = CouchRest.get blue_url
      assert_equal 'rose', blue_copy['confirm']
    end
  end

  def clone_to_db(dbname)
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

  def db
    doc.database
  end

  def root
    db.root
  end

  attr_reader :doc
end
