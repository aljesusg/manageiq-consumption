class ManageIQ::Consumption::InputMeasure < ApplicationRecord
  validates :description, :entity, :group, :fields, :presence => true

  serialize :fields, Array

  self.table_name = "showback_input_measures"

  def name
    "#{entity}::#{group}"
  end

  def self.seed
    seed_data.each do |input_measure_attributtes|
      input_measure_name = input_measure_attributtes[:entity]
      input_measure_group = input_measure_attributtes[:group]
      next if ManageIQ::Consumption::InputMeasure.find_by(:entity => input_measure_name, :group => input_measure_group)
      log_attrs = input_measure_attributtes.slice(:entity, :description, :group, :fields)
      _log.info("Creating consumption input measure with parameters #{log_attrs.inspect}")
      _log.info("Creating #{input_measure_name} consumption input measure...")
      measure_new = create(input_measure_attributtes)
      measure_new.save
      _log.info("Creating #{input_measure_name} consumption input measure... Complete")
    end
  end

  def self.seed_file_name
    @seed_file_name ||= Pathname.new(Gem.loaded_specs['manageiq-consumption'].full_gem_path).join("db", "fixtures", "input_measures.yml")
  end

  def self.seed_data
    File.exist?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end
end
