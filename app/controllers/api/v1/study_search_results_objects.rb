module Api
  module V1
    # contains helper methods for converting search results and studies to plain objects suitable
    # for returning as json
    # intended to be used as an include in controllers which use them, as they rely on instance variables
    module StudySearchResultsObjects
      def search_results_obj
        response_obj = {
          type: params[:type],
          terms: params[:terms],
          term_list: @term_list,
          current_page: @results.current_page.to_i,
          total_studies: @results.total_entries,
          total_pages: @results.total_pages,
          matching_accessions: @matching_accessions,
          preset_search: params[:preset_search],
          match_by_data: @match_by_data
        }
        if @selected_branding_group.present?
          response_obj[:scpbr] = @selected_branding_group.name_as_id
        end
        response_obj[:facets] = @facets.map { |facet| {id: facet[:id], filters: facet[:filters] } }
        response_obj[:studies] = @results.map { |study| study_response_obj(study) }
        response_obj
      end

      def study_response_obj(study)
        if study.is_a?(Study)
          study_obj = {
            study_source: 'SCP',
            accession: study.accession,
            name: study.name,
            description: study.description,
            public: study.public,
            detached: study.detached,
            cell_count: study.cell_count,
            gene_count: study.gene_count,
            study_url: view_study_path(accession: study.accession, study_name: study.url_safe_name) +
              (params[:scpbr].present? ? "?scpbr=#{params[:scpbr]}" : '')
          }
          if @studies_by_facet.present?
            # faceted search was run, so append filter matches
            study_obj[:facet_matches] = @studies_by_facet[study.accession]
          end
          if params[:terms].present?
            search_weight = study.search_weight(@term_list)
            study_obj[:term_matches] = search_weight[:terms].keys
            study_obj[:term_search_weight] = search_weight[:total]
          end
          # if this is an inferred match, use :term_matches for highlighting, but set :inferred_match to true
          if @inferred_accessions.present? && @inferred_accessions.include?(study.accession)
            study_obj[:inferred_match] = true
            inferred_weight = study.search_weight(@inferred_terms)
            study_obj[:term_matches] = inferred_weight[:terms].keys
            study_obj[:term_search_weight] = inferred_weight[:total]
          end
          if @preset_search.present? && @preset_search.accession_list.include?(study.accession)
            study_obj[:preset_match] = true
          end
          if @gene_results.present?
            study_obj[:gene_matches] = @gene_results[:genes_by_study][study.id].uniq
            study_obj[:can_visualize_clusters] = study.can_visualize_clusters?
            is_numeric = study.default_annotation.split('--')[1] == 'numeric'
            study_obj[:is_default_annotation_numeric] = is_numeric
          end
        else
          study_obj = {
            study_source: study[:hca_result] ? 'HCA' : 'TDR',
            accession: study[:accession],
            name: study[:name],
            description: study[:description],
            public: true,
            detached: false,
            hca_project_id: study[:hca_project_id],
            cell_count: 0,
            gene_count: 0,
            study_url: '#',
            file_information: study[:file_information],
            term_matches: @term_list
          }
          if @studies_by_facet.present?
            # faceted search was run, so append filter matches
            study_obj[:facet_matches] = @studies_by_facet[study[:accession]]
          end
        end
        study_obj
      end
    end
  end
end
