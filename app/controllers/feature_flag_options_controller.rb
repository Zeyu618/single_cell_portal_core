# manage feature flag options for any class that is FeatureFlaggalbe
class FeatureFlagOptionsController < ApplicationController
  before_action do
    authenticate_user!
    authenticate_admin
  end

  before_action :set_feature_flaggable_instance, only: %i[edit update]

  # attributes to retrieve enabled models by
  SEARCH_ATTR_BY_MODEL = {
    'study' => %w[accession name],
    'branding_group' => %w[name],
    'user' => %w[email]
  }.freeze

  FEATURE_FLAG_OPTS_PARAMS = %i[id feature_flag_id feature_flaggable_type feature_flaggable_id value _destroy].freeze

  def index
    @feature_flag_info = {}.with_indifferent_access
    FeatureFlag.all.order(name: :asc).each do |feature_flag|
      options = feature_flag.feature_flag_options
      types = SEARCH_ATTR_BY_MODEL.keys.map(&:classify)
      info = types.map { |name| { name => options.where(feature_flaggable_type: name).count } }.reduce({}, :merge)
      info.merge!({ default_value: feature_flag.default_value, description: feature_flag.description })
      @feature_flag_info[feature_flag.name] = info
    end
  end

  # search for a FeatureFlaggable entity
  def find
    unless SEARCH_ATTR_BY_MODEL.keys.include?(params[:class_name])
      redirect_to feature_flag_options_path, alert: "#{params[:class_name].classify} is not FeatureFlaggable" and return
    end

    model_class = self.class.instantiate_class(params[:class_name])
    find_by_method = params[:attribute].to_sym
    instance = model_class.find_by(find_by_method => params[:value])
    if instance.present?
      redirect_to edit_feature_flag_option_path(class_name: params[:class_name], id: instance.id.to_s)
    else
      redirect_to feature_flag_options_path, alert: "Could not find requested #{params[:class_name]}: #{params[:value]}"
    end
  end

  def edit; end

  def update
    updated_entity_params = FeatureFlaggable.merge_default_destroy_param(feature_flag_options_params)
    if @instance.update(updated_entity_params)
      instance_name = view_context.get_instance_label(@instance)
      count = @instance.feature_flag_options.count
      redirect_to feature_flag_options_path, notice: "Feature flags for #{instance_name} saved (#{count} configured flags)"
    else
      render :edit
    end
  end

  # instantiate the instance of the requested class that is FeatureFlaggable
  def self.instantiate_model(class_name, id)
    model_class = instantiate_class(class_name)
    model_class.find(id) if model_class.present?
  end

  def self.instantiate_class(class_name)
    correct_name = class_name.classify
    correct_name.constantize if Object.const_defined?(correct_name)
  end

  private

  def feature_flag_options_params
    # detect which object class this is
    class_name = params.keys.detect { |key| SEARCH_ATTR_BY_MODEL.keys.include? key }
    params.require(class_name).permit(feature_flag_options_attributes: FEATURE_FLAG_OPTS_PARAMS)
  end

  def set_feature_flaggable_instance
    @instance = self.class.instantiate_model(params[:class_name], params[:id])
  end
end
