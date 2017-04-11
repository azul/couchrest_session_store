module CouchRest
  #
  # StorageMissing is used by CouchRest::Model::Rotation to indicate the
  # underlying database is missing.
  #
  # This can happen if rotations are not run frequently enough.
  #
  class StorageMissing < RuntimeError
    attr_reader :db
    def initialize(request, db)
      super(request)
      @db = db.name
      @message = "The database '#{db}' does not exist."
    end
  end
end
