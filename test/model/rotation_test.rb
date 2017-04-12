require 'test_helper'
require 'couchrest/model/rotation'

module CouchRest
  module Model
    class RotationTest < MiniTest::Test
      class Token < CouchRest::Model::Base
        include CouchRest::Model::Rotation
        property :token, String
        rotate_database 'test_rotate', every: 1.day
      end

      TEST_DB_RE = /test_rotate_\d+/

      def setup
        delete_all_dbs
        Time.stub :now, Time.gm(2015, 3, 7, 0) do
          Token.create_database!
          @doc = Token.create!(token: 'aaaa')
          @original_name = Token.rotated_database_name
          @next_db_name = Token.rotated_database_name(Time.gm(2015, 3, 8))
        end
      end

      def teardown
        delete_all_dbs
      end

      def test_initial_db
        assert database_exists?(original_name)
        assert_equal 1, count_dbs
        refute_equal original_name, next_db_name
      end

      def test_do_nothing_yet
        Time.stub :now, Time.gm(2015, 3, 7, 22) do
          Token.rotate_database_now(window: 1.hour)
          assert_equal original_name, Token.rotated_database_name
          assert_equal 1, count_dbs
        end
      end

      def test_create_next_db
        Time.stub :now, Time.gm(2015, 3, 7, 23) do
          Token.rotate_database_now(window: 1.hour)
          assert_equal 2, count_dbs
          assert database_exists?(next_db_name)
        end
      end

      def test_replicate_to_next_db
        Time.stub :now, Time.gm(2015, 3, 7, 23) do
          Token.rotate_database_now(window: 1.hour)
          sleep 0.2 # allow time for documents to replicate
          assert_equal current_token, next_token
        end
      end

      def test_use_next_db
        Time.stub :now, Time.gm(2015, 3, 8) do
          Token.rotate_database_now(window: 1.hour)
          assert_equal 2, count_dbs
          assert_equal next_db_name, Token.rotated_database_name
        end
      end

      def test_next_db_is_independent
        Time.stub :now, Time.gm(2015, 3, 8) do
          Token.rotate_database_now(window: 1.hour)
          sleep 0.2 # allow time for documents to replicate
          current_token.update_attributes(token: 'bbbb')
          assert_equal 'bbbb', current_token.token
          assert_equal 'aaaa', original_token.token
        end
      end

      def test_delete_prior_db
        Time.stub :now, Time.gm(2015, 3, 8) do
          Token.rotate_database_now(window: 1.hour)
        end
        Time.stub :now, Time.gm(2015, 3, 8, 1) do
          Token.rotate_database_now(window: 1.hour)
          assert_equal next_db_name, Token.rotated_database_name
          assert_equal 1, count_dbs
        end
      end

      def test_rotation_after_window
        Time.stub :now, Time.gm(2015, 3, 8, 2) do
          Token.rotate_database_now(window: 1.hour)
          assert_equal next_db_name, Token.rotated_database_name
          sleep 0.2
          assert_equal 'aaaa', current_token.token
        end
      end

      private

      attr_reader :doc, :original_name, :next_db_name

      def current_token
        Token.get(doc.id)
      end

      def original_token
        Token.get(doc.id, database(original_name))
      end

      def next_token
        Token.get(doc.id, database(next_db_name))
      end

      def database(db_name)
        Token.server.database(Token.db_name_with_prefix(db_name))
      end

      def database_exists?(dbname)
        Token.database_exists?(dbname)
      end

      def delete_all_dbs(regexp = TEST_DB_RE)
        Token.server.databases.each do |db|
          Token.server.database(db).delete! if regexp.match(db)
        end
      end

      def count_dbs(regexp = TEST_DB_RE)
        Token.server.databases.grep(regexp).count
      end
    end
  end
end
