def AddMetaToRefinerycmsImages
  def self.up
    add_column ::Image.table_name, :meta, :text
  end
  def self.down
    remove_column ::Image.table_name, :meta
  end
end