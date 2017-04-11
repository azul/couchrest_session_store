require 'active_support/all'
require 'couchrest_model'
require 'couchrest/model/database_method'
require 'couchrest/model/rotating_database'

module CouchRest
  module Model
    #
    # Mixin to rotate the underlying database of a couchrest model
    #
    # including this prevents deleted documents from pileing up.
    #
    module Rotation
      extend ActiveSupport::Concern
      include CouchRest::Model::DatabaseMethod

      included do
        use_database_method :rotated_database_name
      end

      def create(*args)
        super(*args)
      rescue CouchRest::NotFound => exc
        raise storage_missing(exc)
      end

      def update(*args)
        super(*args)
      rescue CouchRest::NotFound => exc
        #
        # TODO: maybe we need to check if it's really the db missing
        # Might as well be the document we are trying to update.
        #
        raise storage_missing(exc)
      end

      def destroy(*args)
        super(*args)
      rescue CouchRest::NotFound => exc
        raise storage_missing(exc)
      end

      private

      # returns a special 'storage missing' exception when the db has
      # not been created. very useful, since this happens a lot and a
      # generic 404 is not that helpful.
      def storage_missing(exc)
        if exc.http_body =~ /no_db_file/
          CouchRest::StorageMissing.new(exc.response, database)
        else
          exc
        end
      end

      module ClassMethods
        #
        # Set up database rotation.
        #
        # base_name -- the name of the db before the rotation number is
        # appended.
        #
        # options -- one of:
        #
        # * :every -- frequency of rotation
        # * :expiration_field - what field to use to determine if a
        #                       document is expired.
        # * :timestamp_field - alternately, what field to use for the
        #                      document timestamp.
        # * :timeout -- used to expire documents with only a timestamp
        #               field (in minutes)
        #
        def rotate_database(base_name, options = {})
          @rotation_base_name = base_name
          @rotation_every = (options.delete(:every) || 30.days).to_i
          @rotation_config = {
            expires: options.delete(:expiration_field),
            timestamp: options.delete(:timestamp_field),
            timeout: options.delete(:timeout)
          }
          if options.any?
            raise ArgumentError,
              'Could not understand options %s' % options.keys
          end
        end

        #
        # Check to see if dbs should be rotated. The :window
        # argument specifies how far in advance we should
        # create the new database (default 1.day).
        #
        # This method relies on the assumption that it is called
        # at least once within each @rotation_every period.
        #
        def rotate_database_now(window: 1.day)
          current = rotating_database
          replication_started = false
          unless current.exist?
            create_rotated_database(current)
            replication_started = true
          end
          create_rotated_database(current + 1) if current.rotate_in? window
          return if current.rotated_since? window
          (current - 2).db.delete! if (current - 2).exist?
          return if replication_started
          (current - 1).db.delete! if (current - 1).exist?
        end

        def rotating_database(name = nil, time: nil)
          name ||= db_name_with_prefix @rotation_base_name
          RotatingDatabase.new server, name,
            frequency: @rotation_every,
            now: time,
            **@rotation_config
        end

        def rotated_database_name(time = nil)
          rotating_database(@rotation_base_name, time: time).name
        end

        def create_database!(name = nil)
          rotating_database.create
        end

        protected

        #
        # Creates database for rotating db given as rotating. Sets up
        # continuous replication from the previous db, if it exists. The
        # assumption is that the source db will be destroyed later, cleaning up
        # the replication once it is no longer needed.
        #
        # This method will also copy design documents if present in
        #  * source db,
        #  * the CouchRest::Model,
        #  * or a database named after rotation_base_name.
        #
        def create_rotated_database(rotating)
          db = rotating.create
          design_doc.sync!(db) if respond_to?(:design_doc, true)
          rotating.copy_design_docs_from_base
          rotating.replicate_from_previous
        end
      end
    end
  end
end
