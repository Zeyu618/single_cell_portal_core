##
# PresetSearch: a collection for storing a "canned" query for a group of studies.  Will always prioritize the studies
# included in the :accession_list over other query results. :search_terms and :facet_filters are arrays of individual
# keyword/phrase or facet filters exactly as they would be passed to the search API
#
# examples of :search_terms and :facet_filters to find HIV human blood studies:
#
#     preset_search.search_terms = ["HIV", "Human", "blood"]
#     preset_search.facet_filters = ["disease:MONDO_0005109", "species:NCBITaxon_9606", "organ:UBERON_0000178"]
#
# It should be noted that the AND logic of keywords + facets in the search API would mean that using the above values
# together would likely result in too few studies being matched - rather one or the other would be a better approach
##

class PresetSearch
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :identifier, type: String
  field :accession_list, type: Array, default: []
  field :search_terms, type: Array, default: []
  field :facet_filters, type: Array, default: []
  field :public, type: Mongoid::Boolean, default: true

  validates_presence_of :name
  validates_uniqueness_of :name
  before_validation :set_identifier, on: :create, if: proc {|attributes| attributes[:name].present?}
  before_validation :sanitize_array_attributes
  validate :ensure_search_terms_are_unique, if: proc {|attributes| attributes[:search_terms].any?}
  validate :ensure_facet_filters_are_unique, if: proc {|attributes| attributes[:facet_filters].any?}
  validate :permitted_studies_exist
  validate :can_return_results

  # format search terms into a query string to use with search API
  def keyword_query_string
    processed_terms = []
    self.search_terms.each do |search_val|
      # spaces or dashes (-) need to be quoted to be treated as single values
      term = search_val.match?(/[\s-]/) ? "\"#{search_val}\"" : search_val
      processed_terms << term
    end
    processed_terms.join(' ')
  end

  def facet_query_string
    self.facet_filters.join('+')
  end

  # extract search_facet identifiers from facet_filters query string
  def get_facet_identifiers
    self.facet_filters.map {|facet_data| facet_data.split(':').first}.flatten
  end

  # extract all filter values
  def get_filter_values
    self.facet_filters.map {|facet_data| facet_data.split(':').last.split(',')}.flatten
  end

  def search_facets
    SearchFacet.where(:identifier.in => self.get_facet_identifiers)
  end

  def study_list
    Study.where(:accession.in => self.accession_list)
  end

  # helper for determining if this search does not contain keywords/facets
  def permitted_studies_only?
    self.facet_filters.empty? && self.search_terms.empty?
  end

  # get an array of matching facets & filters based off of the facet_filters query string
  # this method mimics SearchController#set_search_facets_and_filters and is needed because
  # the above method runs as a :before_filter and cannot be overridden
  def matching_facets_and_filters
    facets_and_filters = []
    self.search_facets.each do |search_facet|
      facet = {id: search_facet.identifier, filters: [], object_id: search_facet.id}
      filter_query = self.facet_filters.detect {|f| f.starts_with?(search_facet.identifier)}
      filter_query.split(':').last.split(',').each do |filter|
        matching_filter = search_facet.filters.detect {|f| f[:id] == filter}
        facet[:filters] << matching_filter if matching_filter.present?
      end
      facets_and_filters << facet if facet[:filters].any?
    end
    facets_and_filters
  end

  private

  # sets a url-safe version of name (for API requests)
  def set_identifier
    self.identifier = self.name.downcase.gsub(/[^a-zA-Z0-9]+/, '-').chomp('-')
  end

  def sanitize_array_attributes
    self.accession_list.reject!(&:blank?)
    self.search_terms.reject!(&:blank?)
    self.facet_filters.reject!(&:blank?)
  end

  # validate all terms are unique - only find duplicates if size mismatch is found on search_terms.uniq call
  def ensure_search_terms_are_unique
    uniques = self.search_terms.dup.uniq
    if uniques != self.search_terms
      duplicates = find_duplicates(self.search_terms)
      errors.add(:search_terms, "contains duplicated values: #{duplicates.join(', ')}")
    end
  end

  # validate requested facets/filters are unique and have no duplicates
  def ensure_facet_filters_are_unique
    duplicate_ids = find_duplicates(self.get_facet_identifiers)
    duplicate_filters = find_duplicates(self.get_filter_values)
    if duplicate_ids.any? || duplicate_filters.any?
      errors.add(:facet_filters, "contains duplicated identifiers/filters: #{[duplicate_ids, duplicate_filters].flatten.compact.join(', ')}")
    end
  end

  # validate that permitted studies exist on save
  def permitted_studies_exist
    unless self.study_list.count == self.accession_list.count
      missing = (self.accession_list - self.study_list.pluck(:accession)).join(', ')
      errors.add(:accession_list, "contains missing studies: #{missing}")
    end
  end

  # validate that this search has potential to return results; it must have an accession_list, search_terms,
  # or facet_filters
  def can_return_results
    if self.accession_list.blank? && self.search_terms.empty? && self.facet_filters.empty?
      errors.add(:base, "You must supply either search terms, facet filters, or an accession list")
    end
  end

  def find_duplicates(terms)
    unique_terms = terms.dup.uniq
    unique_terms.map {|t| t if terms.count(t) > 1}.compact
  end
end
