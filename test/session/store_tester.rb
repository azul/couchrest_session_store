require 'couchrest/session/store'

#
# A simple wrapper around the store that makes testing it easier.
# It exposes the protected methods that are usually triggered by
# the SessionStore super class.
#
# It also hides env as an argument to make live easier.

module CouchRest
  module Session
    class StoreTester
      def initialize
        @store = CouchRest::Session::Store.new(app, {})
        store.create_database!
      end

      def get_session(sid = nil)
        store.send :get_session, env, sid
      end

      def set_session(sid, session, options = {})
        store.send :set_session, env, sid, session, options
      end

      def destroy_session(sid)
        store.send :destroy_session, env, sid, {}
      end

      def cleanup(sessions)
        store.cleanup sessions
      end

      def database
        store.database
      end

      protected

      attr_reader :store

      def env
        {}
      end

      def app
        nil
      end
    end
  end
end
