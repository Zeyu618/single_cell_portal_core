# class for converting from Alexandria convention names to HCA or TIM metadata model names (i.e. columns, not  values)
# this is currently for PoC work on XDSS - eventually this will be replaced by an onotology server that can handle
# conversions programmatically
class FacetNameConverter
  # controlled list of metadata schema names
  SCHEMA_NAMES = %i[alexandria tim hca azul].freeze

  # map of Alexandria metadata convention names to HCA 'short' names
  ALEXANDRIA_TO_HCA = {
    'biosample_id' => 'biosample_id',
    'cell_type' => 'cell_type',
    'donor_id' => 'donor_id',
    'disease' => 'disease',
    'library_preparation_protocol' => 'library_construction_method',
    'organ' => 'organ',
    'organism_age' => 'organism_age',
    'sex' => 'sex',
    'species' => 'genus_species',
    'study_name' => 'project_title',
    'study_description' => 'project_description',
    'accession' => 'project_short_name'
  }.with_indifferent_access.freeze

  # map of Alexandria metadata convention names to namespace Terra Interoperability Model (TIM) names
  ALEXANDRIA_TO_TIM = {
    'biosample_id' => 'dct:identifier',
    'donor_id' => 'prov:wasDerivedFrom',
    'disease' => 'TerraCore:hasDisease',
    'library_preparation_protocol' => 'TerraCore:hasLibraryPrep',
    'organ' => 'TerraCore:hasAnatomicalSite',
    'organism_age' => 'organism_age',
    'sex' => 'TerraCore:hasSex',
    'species' => 'TerraCore:hasOrganismType',
    'study_name' => 'dct:title',
    'study_description' => 'dct:description',
    'accession' => 'rdfs:label'
  }.with_indifferent_access.freeze

  # map of alexandria names to HCA Azul facet names (for searching projects/files via the Azul API)
  ALEXANDRIA_TO_AZUL = {
    'biosample_id' => 'sampleId',
    'cell_type' => 'selectedCellType',
    'disease' => 'sampleDisease',
    'library_construction_protocol' => 'libraryConstructionApproach',
    'organ' => 'organ',
    'organism_age' => 'organismAge',
    'preservation_method' => 'preservationMethod',
    'sex' => 'biologicalSex',
    'species' => 'genusSpecies',
    'study_accession' => 'projectId',
    'study_description' => 'projectDescription',
    'study_name' => 'projectTitle'
  }.with_indifferent_access.freeze

  # inverted mappings of TIM/HCA to Alexandria
  TIM_TO_ALEXANDRIA = ALEXANDRIA_TO_TIM.invert.freeze
  HCA_TO_ALEXANDRIA = ALEXANDRIA_TO_HCA.invert.freeze
  AZUL_TO_ALEXANDRIA = ALEXANDRIA_TO_AZUL.invert.freeze

  # convert a metadata schema column name from one schema to another
  # e.g. FacetNameConverter.convert_schema_column(:alexandria, :tim, 'species') => 'TerraCore:hasOrganismType'
  #
  # * *params*
  #   - +source_schema+ (String, Symbol) => Name of schema to convert from (:alexandria, :hca or :tim)
  #   - +target_schema+ (String, Symbol) => Name of schema to convert to (:alexandria, :hca or :tim)
  #   - +column_name+ (String, Symbol) => column name to convert from source_schema
  #
  # * *returns*
  #   - (String) => String value of requested column/property
  #
  # * *raises*
  #   - (ArgumentError) => if source/target schema do not exist
  def self.convert_schema_column(source_schema = :alexandria, target_schema, column_name)
    invalid_schemas = [source_schema.to_sym, target_schema.to_sym] - SCHEMA_NAMES
    raise ArgumentError, "invalid schema conversion: #{invalid_schemas.join(', ')}" if invalid_schemas.any?

    map_name = "FacetNameConverter::#{source_schema.upcase}_TO_#{target_schema.upcase}"
    if Object.const_defined? map_name
      # perform lookup, but fall back to provided column name if no match is found
      mappings = map_name.constantize
      mappings[column_name] || column_name
    else
      # conversion not possible, so fall back on column_name
      column_name
    end
  end
end
