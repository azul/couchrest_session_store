require 'test_helper'
require 'couchrest/session/document'

module CouchRest
  module Session
    class DocumentTest < MiniTest::Test
      def setup
        CouchRest::Session::Document.database!
      end

      def teardown
        CouchRest::Session::Document.database.delete!
      end

      def test_storing_session
        sid = '1234'
        session = { 'a' => 'b' }
        options = {}
        doc = CouchRest::Session::Document.build_or_update(sid, session, options)
        doc.save
        doc.fetch(sid)
        assert_equal session, doc.to_session
      end

      def test_storing_session_with_conflict
        sid = '1234'
        session = { 'a' => 'b' }
        options = {}
        doc = CouchRest::Session::Document.build_or_update(sid, session, options)
        doc2 = CouchRest::Session::Document.build_or_update(sid, session, options)
        doc.save
        doc2.save
        doc2.fetch(sid)
        assert_equal session, doc2.to_session
      end
    end
  end
end
