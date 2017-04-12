require 'test_helper'
require 'couchrest/model/rotation'
require 'byebug'

module CouchRest
  module Model
    class RotationFilterTest < MiniTest::Test
      class ExpiringToken < CouchRest::Model::Base
        include CouchRest::Model::Rotation
        property :token, String
        property :expires_at, Time
        rotate_database 'test_rotate', every: 1.day, expiration_field: :expires_at
      end

      TEST_DB_RE = /test_rotate_\d+/

      def setup
        delete_all_dbs
        Time.stub :now, Time.gm(2015, 3, 7, 0) do
          ExpiringToken.create_database!
          seed_tokens
        end
      end

      def teardown
        delete_all_dbs
      end

      def test_replicate_to_next_db
        Time.stub :now, Time.gm(2015, 3, 8, 0) do
          ExpiringToken.rotate_database_now(window: 1.hour)
          sleep 0.2 # allow time for documents to replicate
          # design doc + one token is two docs total:
          assert_equal 2, ExpiringToken.database.info['doc_count']
        end
      end

      protected

      def delete_all_dbs(regexp = TEST_DB_RE)
        ExpiringToken.server.databases.each do |db|
          ExpiringToken.server.database(db).delete! if regexp.match(db)
        end
      end

      def seed_tokens
        # one expiry is in the far future because we cannot influence
        # couchs filtering which is based on the current time.
        ExpiringToken.create! token: 'aaaa', expires_at: Time.gm(2015, 3, 7, 22)
        ExpiringToken.create! token: 'aaaa', expires_at: Time.gm(2215, 3, 8, 1)
      end
    end
  end
end
