module Api
  module V1
    module Visualization
      # aggregation controller for methods needed for initial study visualization display
      # the goal of this controller is to be business-logic free, and only amalgamate calls
      # to other controller/service methods when needed to save server round-trips
      class ExploreController < ApiBaseController
        include Concerns::Authenticator
        include Concerns::StudyAware
        include Swagger::Blocks

        before_action :set_current_api_user!
        before_action :set_study
        before_action :check_study_view_permission

        swagger_path '/studies/{study_id}/explore' do
          operation :get do
            key :tags, [
                'Visualization'
            ]
            key :summary, 'Basic study visualization information'
            key :description, 'Returns overview of visualization properties for the given study'
            key :operationId, 'api_v1_studies_explore_path'
            parameter do
              key :name, :study_id
              key :in, :path
              key :description, 'ID of Study'
              key :required, true
              key :type, :string
            end
            response 200 do
              key :description, 'JSON of study visualization properties'
            end
            response 401 do
              key :description, ApiBaseController.unauthorized
            end
            response 403 do
              key :description, ApiBaseController.forbidden('edit Study')
            end
            response 404 do
              key :description, ApiBaseController.not_found(Study)
            end
            response 406 do
              key :description, ApiBaseController.not_acceptable
            end
          end
        end

=begin
        cluster {Object}: Cluster properties for visualization, if present

        taxonNames {Array} List of species scientific names

        inferCNVIdeogramFiles {Object}: inferCNV ideogram files, by file ID

        uniqueGenes (Array): List of unique gene names, for e.g. autocomplete

        ---

        clusterPointAlpha {Float}: opacity of cluster points in this study

        clusterGroupNames {Array}: all possible cluster groups for a study
=end

        def show
          default_cluster = @study.default_cluster
          ideogram_files = ExpressionVizService.get_infercnv_ideogram_files(@study)

          if default_cluster.present?
            cluster = {
              numPoints: default_cluster.points,
              isSubsampled: default_cluster.subsampled?
            }
          else
            cluster = nil
          end

          explore_props = {
            cluster: cluster,
            taxonNames: @study.expressed_taxon_names,
            inferCNVIdeogramFiles: ideogram_files,
            uniqueGenes: @study.unique_genes,
            clusterGroupNames: ClusterVizService.load_cluster_group_options(@study),
            spatialGroupNames: ClusterVizService.load_spatial_options(@study),
            clusterPointAlpha: @study.default_cluster_point_alpha
          }

          render json: explore_props
        end

        swagger_path '/studies/{study_id}/explore/cluster_options' do
          operation :get do
            key :tags, [
                'Visualization'
            ]
            key :summary, 'Basic study visualization information'
            key :description, 'Returns overview of visualization properties for the given study'
            key :operationId, 'api_v1_studies_explore_cluster_options_path'
            parameter do
              key :name, :study_id
              key :in, :path
              key :description, 'ID of Study'
              key :required, true
              key :type, :string
            end
            response 200 do
              key :description, 'Annotation list, default_cluster, and subsampling thresholds'
            end
            response 401 do
              key :description, ApiBaseController.unauthorized
            end
            response 403 do
              key :description, ApiBaseController.forbidden('edit Study')
            end
            response 404 do
              key :description, ApiBaseController.not_found(Study)
            end
            response 406 do
              key :description, ApiBaseController.not_acceptable
            end
          end
        end

        def cluster_options
          render json: AnnotationVizService.get_study_annotation_options(@study, current_api_user)
        end
      end

    end
  end
end
