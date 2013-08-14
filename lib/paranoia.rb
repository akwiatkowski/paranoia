module ActiveRecord
  module Validations
    class UniquenessValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        finder_class = find_finder_class_for(record)
        table = finder_class.arel_table

        coder = record.class.serialized_attributes[attribute.to_s]

        if value && coder
          value = coder.dump value
        end

        relation = build_relation(finder_class, table, attribute, value)
        relation = relation.and(table[finder_class.primary_key.to_sym].not_eq(record.send(:id))) if record.persisted?
        # Turn off uniq validation to deleted records
        relation = relation.and(table[:deleted_at].eq(nil)) if record.class.paranoid? and not options[:without_deleted] == false

        Array.wrap(options[:scope]).each do |scope_item|
          scope_value = record.read_attribute(scope_item)
          relation = relation.and(table[scope_item].eq(scope_value))
        end

        if finder_class.unscoped.where(relation).exists?
          record.errors.add(attribute, :taken, options.except(:case_sensitive, :scope).merge(:value => value))
        end
      end
    end
  end
end


module Paranoia
  def self.included(klazz)
    klazz.extend Query
  end

  module Query
    def paranoid?
      true
    end

    def only_deleted
      scoped.tap { |x| x.default_scoped = false }.where("#{self.table_name}.deleted_at IS NOT NULL")
    end
    alias :deleted :only_deleted

    def with_deleted
      scoped.tap { |x| x.default_scoped = false }
    end
  end

  def destroy
    run_callbacks(:destroy) { delete }
  end

  def delete
    return if new_record? or destroyed?
    update_attribute_or_column :deleted_at, Time.now
  end

  def restore!
    update_attribute_or_column :deleted_at, nil
  end
  alias :restore :restore!

  def destroyed?
    !self.deleted_at.nil?
  end

  alias :deleted? :destroyed?

  private

  # Rails 3.1 adds update_column. Rails > 3.2.6 deprecates update_attribute, gone in Rails 4.
  def update_attribute_or_column(*args)
    respond_to?(:update_column) ? update_column(*args) : update_attribute(*args)
  end
end

class ActiveRecord::Base
  def self.acts_as_paranoid
    alias :destroy! :destroy
    alias :delete! :delete
    include Paranoia
    default_scope { where(deleted_at: nil) }
  end

  def self.paranoid?
    false
  end

  def paranoid?
    self.class.paranoid?
  end

  # Override the persisted method to allow for the paranoia gem.
  # If a paranoid record is selected, then we only want to check
  # if it's a new record, not if it is "destroyed".
  def persisted?
    paranoid? ? !new_record? : super
  end
end
