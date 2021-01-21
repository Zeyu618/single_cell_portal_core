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
            render(json: {error: "Study #{@study.accession} does not support expression rendering"}, status: 400) and return
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
          annotation = AnnotationVizService.get_selected_annotation(@study,
                                                                    cluster,
                                                                    params[:annotation_name],
                                                                    params[:annotation_type],
                                                                    params[:annotation_scope])
          subsample = params[:subsample].blank? ? nil : params[:subsample].to_i
          genes = RequestUtils.get_genes_from_param(@study, params[:genes])
          if genes.empty?
            render json: {error: 'You must supply at least one gene'}, status: 422
          else
            render_data = ExpressionVizService.get_global_expression_render_data(
              study: @study,
              subsample: subsample,
              genes: genes,
              cluster: cluster,
              selected_annotation: annotation,
              boxpoints: params[:boxpoints],
              consensus: params[:consensus],
              current_user: current_api_user
            )
            render json: render_data, status: 200
          end
        end

        # this is intended to provide morpheus compatibility, so it returns plain text, instead of json
        def render_heatmap
          cluster = ClusterVizService.get_cluster_group(@study, params)

          collapse_by = params[:row_centered]
          genes = RequestUtils.get_genes_from_param(@study, params[:genes])

          expression_data = ExpressionVizService.get_morpheus_text_data(
              genes: genes, cluster: cluster, collapse_by: collapse_by, file_type: :gct
          )

          render plain: expression_data, status: 200
        end


      end
    end
  end
end
