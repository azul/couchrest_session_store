module CouchRest
  module Model
    #
    # Helper class to keep track of the properties of databases
    # during rotation
    #
    # used by CouchRest::Model::Rotation
    #
    class RotatingDatabase

      def initialize(server, basename, frequency: , now: nil, **config_args)
        @server = server
        @basename = basename
        @frequency = frequency
        @now = now || Time.now.utc
        @config = config_args
      end

      def count
        now.to_i / frequency.to_i
      end

      def name
        "#{basename}_#{count}"
      end

      def ==(other)
        name == other.name
      end

      def exist?(path = name)
        CouchRest.head "#{server.uri}/#{path}"
        return true
      rescue CouchRest::NotFound
        return false
      end

      #
      # create a new empty database.
      #
      def create
        @db = server.database! name
        create_rotation_filter
        return db
      end

      def db
        @db ||= server.database name
      end

      def copy_design_docs_from_base
        if exist?(basename)
          base_db = server.database(basename)
          copy_design_docs base_db
        end
      end

      def replicate_from_previous
        previous = self - 1
        if previous.exist?
          # just to make sure it exists
          previous.create_rotation_filter
          from_db = server.database(previous.name)
          replicate_from_db(from_db)
        end
      end

      # will the database be rotated in the given timespan
      def rotate_in?(seconds)
        (now + seconds).to_i / frequency.to_i > count
      end

      # has the database rotated within the given timespan
      def rotated_since?(seconds)
        (now - seconds).to_i / frequency.to_i < count
      end

      def +(steps)
        after steps * frequency
      end

      def -(steps)
        self + (-1 * steps)
      end

      def after(seconds)
        self.class.new server, basename,
          frequency: frequency,
          now: now + seconds,
          **config
      end

      def create_rotation_filter
        name = 'rotation_filter'
        filters = { 'not_expired' => filter_string }
        db.save_doc('_id' => "_design/#{name}", 'filters' => filters)
      rescue CouchRest::Conflict
      end

      protected
      attr_reader :server, :basename, :frequency, :now, :config

      def copy_design_docs(source)
        params = {
          startkey: '_design/',
          endkey: '_design0',
          include_docs: true
        }
        source.documents(params) do |doc_hash|
          design = doc_hash['doc']
          begin
            db.get(design['_id'])
          rescue CouchRest::NotFound
            design.delete('_rev')
            db.save_doc(design)
          end
        end
      end

      #
      # Replicates documents from_db to to_db, skipping documents that have
      # expired or been deleted.
      #
      # NOTE: It would be better if we could do this:
      #
      #   from_db.replicate_to(to_db, true, false,
      #     :filter => 'rotation_filter/not_expired')
      #
      # But replicate_to() does not support a filter argument, so we call
      # the private method replication() directly.
      #
      def replicate_from_db(source)
        source.send :replicate, db, true,
          source: source.name,
          filter: 'rotation_filter/not_expired'
      end

      def filter_string
        if expires
          NOT_EXPIRED_FILTER % { expires: expires }
        elsif timestamp && timeout
          NOT_TIMED_OUT_FILTER %
            { timestamp: timestamp, timeout: (60 * timeout) }
        else
          NOT_DELETED_FILTER
        end
      end

      def expires
        config[:expires]
      end

      def timestamp
        config[:timestap]
      end

      def timeout
        config[:timeout]
      end

      #
      # Three different filters, depending on how the model is set up.
      #
      # NOT_EXPIRED_FILTER is used when there is a single field that
      # contains an absolute time for when the document has expired. The
      #
      # NOT_TIMED_OUT_FILTER is used when there is a field that records the
      # timestamp of the last time the document was used. The expiration in
      # this case is calculated from the timestamp plus @timeout.
      #
      # NOT_DELETED_FILTER is used when the other two cannot be.
      #
      NOT_EXPIRED_FILTER = '' +
        %[function(doc, req) {
                               if (doc._deleted) {
                                 return false;
                               } else if (typeof(doc.%{expires}) != "undefined") {
                                 return Date.now() < (new Date(doc.%{expires})).getTime();
                               } else {
                                 return true;
                               }
                             }]

      NOT_TIMED_OUT_FILTER = '' +
      %[function(doc, req) {
                                 if (doc._deleted) {
                                   return false;
                                 } else if (typeof(doc.%{timestamp}) != "undefined") {
                                   return Date.now() < (new Date(doc.%{timestamp})).getTime() + %{timeout};
                                 } else {
                                   return true;
                                 }
                               }]

      NOT_DELETED_FILTER = '' +
      %[function(doc, req) {
                               return !doc._deleted;
                             }]
    end
  end
end
