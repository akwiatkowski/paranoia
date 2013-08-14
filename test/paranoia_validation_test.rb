require 'test/unit'
require 'active_record'
require File.expand_path(File.dirname(__FILE__) + '/../lib/paranoia')

DB_FILE = 'tmp/test_db'

FileUtils.mkdir_p File.dirname(DB_FILE)
FileUtils.rm_f DB_FILE

ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => DB_FILE
ActiveRecord::Base.connection.execute 'CREATE TABLE users (id INTEGER NOT NULL PRIMARY KEY, email STRING, deleted_at DATETIME)'

class ParanoiaValidationTest < Test::Unit::TestCase
  def test_uniq_validation
    email = 'test@test.com'
    u = User.new(:email => email)
    u.save!
    u.delete

    assert_equal 0, User.count
    assert_equal 1, User.unscoped.count

    v = User.new(:email => email)
    assert_equal v.valid?, true
    v.save!

    y = User.new(:email => email)
    assert_equal y.valid?, false
  end

  private
  def get_featureful_model
    FeaturefulModel.new(:name => 'not empty')
  end
end

# Helper classes

class User < ActiveRecord::Base
  acts_as_paranoid
  validates_uniqueness_of :email
end