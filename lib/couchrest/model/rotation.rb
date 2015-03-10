module CouchRest
  module Model
    module Rotation
      extend ActiveSupport::Concern
      include CouchRest::Model::DatabaseMethod

      included do
        use_database_method :rotated_database_name
      end

      module ClassMethods
        def rotate_database(base_name, options={})
          @rotation_base_name = base_name
          @rotation_every = (options[:every] || 30.days).to_i
          @expiration_field = options[:expires] || :expires
        end

        #
        # Check to see if dbs should be rotated. The :window
        # argument specifies how far in advance we should
        # create the new database (default 1.day).
        #
        # This method relies on the assumption that it is called
        # at least once within each @rotation_every period.
        #
        def rotate_database_now(options={})
          window = options[:window] || 1.day

          now = Time.now.utc
          current_name = rotated_database_name(now)
          current_count = now.to_i/@rotation_every

          next_time = window.from_now.utc
          next_name = rotated_database_name(next_time)
          next_count = current_count+1

          prev_name = current_name.sub(/(\d+)$/) {|i| i.to_i-1}
          replication_started = false
          old_name = prev_name.sub(/(\d+)$/) {|i| i.to_i-1} # even older than prev_name
          trailing_edge_time = window.ago.utc

          if !database_exists?(current_name)
            # we should have created the current db earlier, but if somehow
            # it is missing we must make sure it exists.
            create_new_rotated_database(:from => prev_name, :to => current_name)
            replication_started = true
          end

          if next_time.to_i/@rotation_every >= next_count && !database_exists?(next_name)
            # time to create the next db in advance of actually needing it.
            create_new_rotated_database(:from => current_name, :to => next_name)
          end

          if trailing_edge_time.to_i/@rotation_every == current_count
            # delete old dbs, but only after window time has past since the last rotation
            if !replication_started && database_exists?(prev_name)
              # delete previous, but only if we didn't just start replicating from it
              self.server.database(db_name_with_prefix(prev_name)).delete!
            end
            if database_exists?(old_name)
              # there are some edge cases, when rotate_database_now is run
              # infrequently, that an older db might be left around.
              self.server.database(db_name_with_prefix(old_name)).delete!
            end
          end
        end

        def rotated_database_name(time=nil)
          unless @rotation_base_name && @rotation_every
            raise ArgumentError.new('missing @rotation_base_name or @rotation_every')
          end
          time ||= Time.now.utc
          units = time.to_i / @rotation_every.to_i
          "#{@rotation_base_name}_#{units}"
        end

        #
        # create a new empty database.
        #
        def create_database!
          db = self.database!
          if self.respond_to?(:design_doc)
            design_doc.sync!(db)
          end
          return db
        end

        protected

        #
        # Creates database named by options[:to]. Optionally, set up
        # continuous replication from the options[:from] db, if it exists. The
        # assumption is that the from db will be destroyed later, cleaning up
        # the replication once it is no longer needed.
        #
        # This method will also copy design documents if present in the from
        # db, in the CouchRest::Model, or in a database named after
        # @rotation_base_name.
        #
        def create_new_rotated_database(options={})
          from = options[:from]
          to = options[:to]
          to_db = self.server.database!(db_name_with_prefix(to))
          if database_exists?(@rotation_base_name)
            base_db = self.server.database(db_name_with_prefix(@rotation_base_name))
            copy_design_docs(base_db, to_db)
          elsif self.respond_to?(:design_docs)
            self.design_docs.each do |design|
              design.migrate(to_db)
            end
          end
          if from && from != to && database_exists?(from)
            from_db = self.server.database(db_name_with_prefix(from))
            replicate_old_to_new(from_db, to_db)
          end
        end

        def copy_design_docs(from, to)
          params = {:startkey => '_design/', :endkey => '_design0', :include_docs => true}
          from.documents(params) do |doc_hash|
            design = doc_hash['doc']
            begin
              to.get(design['_id'])
            rescue RestClient::ResourceNotFound
              design.delete('_rev')
              to.save_doc(design)
            end
          end
        end

        def create_filter(db, name, filters)
          db.save_doc("_id" => "_design/#{name}", "filters" => filters)
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
        def replicate_old_to_new(from_db, to_db)
          create_filter(from_db, 'rotation_filter', {"not_expired" => NOT_EXPIRED_FILTER % {:expires => @expiration_field}})
          from_db.send(:replicate, to_db, true, :source => from_db.name, :filter => 'rotation_filter/not_expired')
        end

        NOT_EXPIRED_FILTER = "" +
%[function(doc, req) {
  if (doc._deleted) {
    return false;
  } else if (typeof(doc.%{expires}) != "undefined") {
    return Date.now() < (new Date(doc.%{expires})).getTime();
  } else {
    return true;
  }
}]
      end
    end
  end
end
