require 'test_helper'
require 'couchrest_model'
require 'couchrest/model/rotation'

#
# This doesn't really test much, but is useful if you want to see what happens
# when you have a lot of documents.
#

class StressTest < MiniTest::Test
  COUNT = 20 # change to 200,000 if you dare
  FRESH_COUNT = COUNT / 10 # number of non expired docs

  class Stress < CouchRest::Model::Base
    include CouchRest::Model::Rotation
    property :token, String
    property :expires_at, Time
    rotate_database 'stress_test', every: 1.day, expiration_field: :expires_at
  end

  def test_stress
    delete_all_dbs(/^couchrest_stress_test_\d+$/)
    Stress.database!
    create_expired_records
    create_fresh_records

    Time.stub :now, 1.day.from_now do
      Stress.rotate_database_now(window: 1.hour)
      sleep 0.5
      assert_only_fresh_records
    end
  end

  private

  def create_expired_records
    COUNT.times { create_stress 1.hour.ago.utc }
  end

  # The couch time does not change in our Time stub.
  # So if docs expire 1 hour from now couch will still think
  # they are fresh even if ruby thinks we're one day ahead.
  def create_fresh_records
    FRESH_COUNT.times { create_stress 1.hour.from_now.utc }
  end

  def create_stress(expiry)
    Stress.create! token: SecureRandom.hex(32), expires_at: expiry
  end

  def assert_only_fresh_records
    assert_equal FRESH_COUNT + 1, Stress.database.info['doc_count']
  end

  def delete_all_dbs(regexp = TEST_DB_RE)
    Stress.server.databases.each do |db|
      Stress.server.database(db).delete! if regexp.match(db)
    end
  end
end
