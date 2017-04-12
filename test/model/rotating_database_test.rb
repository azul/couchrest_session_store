require 'test_helper'
require 'couchrest/model/rotating_database'
require 'couchrest'

module CouchRest
  module Model
    class RotatingDatabaseTest < Minitest::Test
      def setup
        @rotating = rotating_database 'prefixed_name', frequency: frequency
      end

      def test_name
        count = Time.now.utc.to_i / frequency.to_i
        assert_equal "prefixed_name_#{count}", rotating.name
      end

      def test_exist
        CouchRest.stub :head, {} do
          assert_predicate rotating, :exist?
        end
      end

      def test_not_existing
        raises_not_found = ->(_url) { raise CouchRest::NotFound }
        CouchRest.stub :head, raises_not_found do
          refute_predicate rotating, :exist?
        end
      end

      def test_rotate_in
        assert rotating.rotate_in?(frequency)
        refute rotating.rotate_in?(0)
      end

      def test_rotated_since
        assert rotating.rotated_since?(frequency)
        refute rotating.rotated_since?(0)
      end

      def test_create
        server.expect :database!, db, [String]
        db.expect :save_doc, true, [Hash]
        rotating.create
        server.verify
        db.verify
      end

      def test_copy_design_docs_from_base; end

      def test_create_next; end

      def test_delete; end

      protected

      attr_reader :rotating

      def frequency
        30.days
      end

      def rotating_database(*args)
        CouchRest::Model::RotatingDatabase.new server, *args
      end

      def server
        @server ||= server_mock
      end

      def db
        @db ||= Minitest::Mock.new
      end

      def server_mock
        mock = Minitest::Mock.new
        def mock.uri
          ''
        end
        mock
      end
    end
  end
end
