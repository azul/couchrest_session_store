require 'couchrest/session/utility'
require 'couchrest/model/rotation'
require 'couchrest/storage_missing'
require 'time'

module CouchRest
  module Session
    #
    # The Session Record itself.
    #
    # We use a simple CouchRest::Document and include the parts
    # of CouchRest::Model that seem useful.
    #
    # We are rotating the database so expired sessions get cleaned
    # up without leaving cruft in the database.
    #
    # Has a few helper class methods and takes care of creating
    # its design doc when the database is created.
    #
    class Document < CouchRest::Document
      include CouchRest::Model::Configuration
      include CouchRest::Model::Connection
      include CouchRest::Model::Rotation
      include Utility

      rotate_database 'sessions',
        every: 1.month, expiration_field: :expires

      def self.fetch(sid)
        allocate.tap do |session_doc|
          session_doc.fetch(sid)
        end
      end

      def self.build(sid, session, options = {})
        new(CouchRest::Document.new('_id' => sid)).tap do |session_doc|
          session_doc.update session, options
        end
      end

      def self.build_or_update(sid, session, options = {})
        options[:marshal_data] = true if options[:marshal_data].nil?
        doc = fetch(sid)
        doc.update(session, options)
        return doc
      rescue CouchRest::NotFound
        build(sid, session, options)
      end

      def self.find_by_expires(options = {})
        options[:reduce] ||= false
        design = database.get! '_design/Session'
        response = design.view :by_expires, options
        response['rows']
      end

      def self.create_database!(name = nil)
        db = super(name)
        begin
          db.get!('_design/Session')
        rescue CouchRest::NotFound
          save_design_doc
        end
        db
      end

      def self.save_design_doc
        file = File.expand_path('../../../../design/Session.json', __FILE__)
        string = File.read file
        design = JSON.parse string
        database.save_doc(design.merge('_id' => '_design/Session'))
      end

      def initialize(doc)
        @doc = doc
      end

      def fetch(sid = nil)
        @doc = database.get!(sid || doc['_id'])
      end

      def to_session
        session = if doc['marshalled']
                    unmarshal(doc['data'])
                  else
                    doc['data']
                  end
        session
      end

      def delete
        database.delete_doc(doc)
      end

      def update(session, options)
        # clean up old data but leave id and revision intact
        doc.reject! { |k, _v| k[0] != '_' }
        doc.merge! data_for_doc(session, options)
      end

      def save
        database.save_doc(doc)
      rescue CouchRest::Conflict
        fetch
        retry
      rescue CouchRest::NotFound => exc
        if exc.http_body =~ /no_db_file/
          exc = CouchRest::StorageMissing.new(exc.response, database)
        end
        raise exc
      end

      def expired?
        expires && expires < Time.now
      end

      protected

      def data_for_doc(session, options)
        { 'data'       => options[:marshal_data] ? marshal(session) : session,
          'marshalled' => options[:marshal_data],
          'expires'    => expiry_from_options(options) }
      end

      def expiry_from_options(options)
        expire_after = options[:expire_after]
        expire_after && (Time.now + expire_after).utc
      end

      def expires
        doc['expires'] && Time.iso8601(doc['expires'])
      end

      attr_reader :doc
    end
  end
end
