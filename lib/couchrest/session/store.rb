require 'forwardable'
require 'couchrest/session/document'
require 'action_dispatch' #/session/abstract_store'
#
# The Session Store itself.
#
# This is mostly a thin wrapper around CouchRest::Session::Document that
# * implements the ActionDispatch::Session::AbstractStore interface
# * offers some helper functions for dealing with the entire store
#
# Most of the functionality still happens in CouchRest::Session::Document
# and we use Forwardable to define delegators for that.
#
class CouchRest::Session::Store < ActionDispatch::Session::AbstractStore
  extend Forwardable

  # delegate configure to document
  def self.configure(*args, &block)
    CouchRest::Session::Document.configure(*args, &block)
  end

  def initialize(app, options = {})
    super
    @options = options
    use_database @options[:database] if @options[:database]
  end

  def cleanup(rows)
    rows.each do |row|
      doc = fetch(row['id'])
      doc.delete
    end
  end

  def expired
    find_by_expires startkey: 1, endkey: Time.now.utc.iso8601
  end

  def never_expiring
    find_by_expires endkey: 1
  end

  private

  def_delegators CouchRest::Session::Document,
    :use_database,
    :create_database!,
    :database,
    :fetch,
    :find_by_expires,
    :build_or_update

  def get_session(_env, sid)
    session = fetch_session(sid)
    session ? [sid, session] : [generate_sid, {}]
  rescue CouchRest::NotFound
    # session data does not exist anymore
    return [sid, {}]
  rescue CouchRest::Unauthorized,
         Errno::EHOSTUNREACH,
         Errno::ECONNREFUSED
    # can't connect to couch. We add some status to the session
    # so the app can react. (Display error for example)
    return [sid, { '_status' => { 'couch' => 'unreachable' } }]
  end

  def set_session(_env, sid, session, options)
    raise CouchRest::Unauthorized if design_doc_id?(sid)
    doc = build_or_update(sid, session, options)
    doc.save
    return sid
    # if we can't store the session we just return false.
  rescue CouchRest::Unauthorized,
         CouchRest::RequestFailed,
         Errno::EHOSTUNREACH,
         Errno::ECONNREFUSED
    return false
  end

  def destroy_session(_env, sid, options)
    doc = secure_get(sid)
    doc.delete
    generate_sid unless options[:drop]
  rescue CouchRest::NotFound
    # already destroyed - we're done.
    generate_sid unless options[:drop]
  end

  def fetch_session(sid)
    return nil unless sid
    doc = secure_get(sid)
    doc.to_session unless doc.expired?
  end

  # prevent access to design docs
  # this should be prevented on a couch permission level as well.
  # but better be save than sorry.
  def secure_get(sid)
    raise CouchRest::NotFound if design_doc_id?(sid)
    fetch(sid)
  end

  def design_doc_id?(sid)
    %r{^_design/(.*)} =~ sid
  end
end
