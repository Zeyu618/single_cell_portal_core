require 'integration_test_helper'
require 'api_test_helper'
require 'test_helper'
require 'includes_helper'

class AnalysisConfigurationsControllerTest < ActionDispatch::IntegrationTest

  before(:all) do
    @user = FactoryBot.create(:admin_user, test_array: @@users_to_clean)
    @analysis_configuration = AnalysisConfiguration.create(
      namespace: 'single-cell-portal', name: 'split-cluster', snapshot: 1, user: @user,
      configuration_namespace: 'single-cell-portal', configuration_name: 'split-cluster', configuration_snapshot: 2,
      description: 'This is a test description.'
    )
  end

  after(:all) do
    AnalysisConfiguration.destroy_all
  end

  def setup
    sign_in_and_update @user
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  test 'should get index page' do
    get analysis_configurations_path
    assert_response 200, 'Did not successfully load analysis configurations index page'
    assert_select 'tr.analysis-configuration-entry', 1, 'Did not find any analysis configuration entries'
  end

  test 'should get detail page' do
    get analysis_configuration_path(@analysis_configuration)
    assert_response 200, "Did not successfully load detail page for #{@analysis_configuration.identifier}"
    assert_select 'div#analysis-parameters', 1, 'Did not find analysis parameters div'
    assert_select 'form.analysis-parameter-form', 2, 'Did not find correct number of analysis parameter entries'
    assert_select 'form.input-analysis-parameter', 1, 'Did not find correct number of inputs'
    assert_select 'form.output-analysis-parameter', 1, 'Did not find correct number of outputs'
    assert_select 'textarea#analysis_configuration_description', text: @analysis_configuration.description
  end

  test 'should create and delete analysis configuration' do
    analysis_configuration_params = {
      analysis_configuration: {
        namespace: 'single-cell-portal',
        name: 'split-cluster',
        snapshot: 3,
        user_id: @user.id,
        configuration_namespace: 'single-cell-portal',
        configuration_name: 'split-cluster',
        configuration_snapshot: 4
      }
    }
    post analysis_configurations_path, params: analysis_configuration_params
    follow_redirect!
    assert_response 200, 'Did not redirect successfully after creating analysis configuration'
    get analysis_configurations_path
    new_config = AnalysisConfiguration.find_by(namespace: 'single-cell-portal', name: 'split-cluster', snapshot: 3)
    assert new_config.present?, 'Analysis configuration did not persist'
    inputs = new_config.analysis_parameters.inputs
    assert inputs.size == 2, "Did not find correct number of input parameters, expected 2 but found #{inputs.size}"
    outputs = new_config.analysis_parameters.outputs
    assert outputs.size == 2, "Did not find correct number of outputs parameters, expected 2 but found #{outputs.size}"
    file_param = outputs.detect {|p| p.parameter_name == 'run_split_cluster.output_clusters'}
    non_file_param = outputs.detect {|p| p.parameter_name == 'run_split_cluster.output_path'}
    assert file_param.is_output_file?, "Did not correct determine output file for #{file_param.config_param_name}"
    assert !non_file_param.is_output_file?, "Did not correct determine non-output file for #{file_param.config_param_name}"
    delete analysis_configuration_path(new_config)
    follow_redirect!
    assert_response 200, 'Did not successfully redirect after deleting analysis configuration'
    assert AnalysisConfiguration.count == 1,
           "Did not successfully delete analysis configuration, found #{AnalysisConfiguration.count} instead of 1"
  end
end
