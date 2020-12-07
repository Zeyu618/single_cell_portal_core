module Api
  module V1
    module Visualization
      # API methods for visualizing expression data
      # does NOT contain methods for editing expression data
      class ExpressionController < ApiBaseController
        include Concerns::Authenticator
        include Concerns::StudyAware
        include Concerns::ApiCaching
        include Swagger::Blocks

        before_action :set_current_api_user!
        before_action :set_study
        before_action :check_study_view_permission
        before_action :check_api_cache!
        after_action :write_api_cache!

        # Returns the specified expression data for the gene within the given study, optimized for rendering
        # by the SCP UI.
        # We agreed that there would be no swagger docs for this endpoint, as it is not intended
        # to be used other than by the SCP UI, and may change dramatically
        def show
          if (!@study.has_expression_data? || !@study.can_visualize_clusters?)
            render json: {error: "Study #{@study.accession} does not support expression rendering"}, status: 400
          end
          data_type = params[:data_type]
          if (data_type == 'violin')
            render_violin
          elsif (data_type == 'heatmap')
            render_heatmap
          else
            render json: {error: "Unknown expression data type: #{data_type}"}, status: 400
          end
        end

        def render_violin
          cluster = ClusterVizService.get_cluster_group(@study, params)
          annotation = ExpressionVizService.get_selected_annotation(@study,
                                                                    cluster,
                                                                    params[:annotation_name],
                                                                    params[:annotation_type],
                                                                    params[:annotation_scope])
          subsample = params[:subsample].blank? ? nil : params[:subsample].to_i
          gene = @study.genes.by_name_or_id(params[:gene], @study.expression_matrix_files.map(&:id))

          render_data = ExpressionVizService.get_global_expression_render_data(
            @study, subsample, gene, cluster, annotation, params[:boxpoints], current_api_user
          )
          render json: render_data, status: 200
        end

        # this is intended to provide morpheus compatibility, so it returns plain text, instead of json
        def render_heatmap
          cluster = ClusterVizService.get_cluster_group(@study, params)
          terms = RequestUtils.sanitize_search_terms(params[:genes]).split(',')
          matrix_ids = @study.expression_matrix_files.map(&:id)
          collapse_by = params[:row_centered]

          genes = []
          terms.each do |term|
            matches = @study.genes.by_name_or_id(term, matrix_ids)
            unless matches.empty?
              genes << matches
            end
          end
          expression_data = ExpressionVizService.get_morpheus_text_data(
              genes: genes, cluster: cluster, collapse_by: collapse_by, file_type: :gct
          )

          render plain: expression_data, status: 200
        end
      end
    end
  end
end
