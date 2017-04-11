#
# Simple Utility Class for CouchRest::Session::Document
#
# currently only handles marshaling
#
module CouchRest
  module Session
    module Utility
      module_function

      def marshal(data)
        ::Base64.encode64(Marshal.dump(data)) if data
      end

      def unmarshal(data)
        Marshal.load(::Base64.decode64(data)) if data
      end
    end
  end
end
