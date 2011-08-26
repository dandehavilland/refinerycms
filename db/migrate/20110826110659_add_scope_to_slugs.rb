class AddScopeToSlugs < ActiveRecord::Migration
  def self.up
    ::Page.all.each do |page|
      page.slug.update_attributes(:scope => page.parent_id) if page.slug.present?
    end
  end

  def self.down
    ::Page.all.each do |page|
      page.slug.update_attributes(:scope => nil) if page.slug.present?
    end
  end
end
