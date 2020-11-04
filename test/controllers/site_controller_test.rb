require "integration_test_helper"

class SiteControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @test_user = User.find_by(email: 'testing.user@gmail.com')
    auth_as_user(@test_user)
    sign_in @test_user
    @study = Study.first
  end

  teardown do
    user = User.find_by(email: 'testing.user@gmail.com')
    reset_user_tokens(user)
  end

  test 'should redirect to home page from bare domain' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    get '/'
    assert_response 302, "Did not receive correct HTTP status code, expected 302 but found #{status}"
    assert_redirected_to site_path, "Did not provide correct redirect, should have gone to #{site_path} but found #{path}"
    follow_redirect!
    assert_equal(site_path, path, "Redirect did not successfully complete, #{site_path} != #{path}")
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should redirect to correct study name url' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    correct_study_url = view_study_path(accession: @study.accession, study_name: @study.url_safe_name)
    incorrect_study_url = view_study_path(accession: @study.accession, study_name: "bogus_name")
    get incorrect_study_url
    assert_response 302, 'Did not redirect to correct url'
    assert_redirected_to correct_study_url,  "Url did not redirected successfully"
    follow_redirect!
    assert_equal(correct_study_url, path, "Url is #{path}. Expected #{correct_study_url}")
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test "should create and delete deployment notification banner" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    deployment_notification_params = {
        deployment_notification: {
            deployment_time: Time.zone.now,
            message: "Testing deployment notification banner"
        }
    }

    post create_deployment_notification_path, params: deployment_notification_params, xhr:true
    get site_path
    assert_select '.notification-banner', 1,"Notification banner did not render to page"
    delete delete_deployment_notification_path
    follow_redirect!
    assert_response 200, 'Did not redirect successfully after banner was deleted'
    # Ensure page does not contain notification banner
    assert_select ".notification-banner", false, "Notification banner was not deleted and still is present on page."
  end

  test 'should fall back to cell metadata on invalid annotation request' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    cluster = @study.cluster_groups.first
    annotation = 'does-not-exist--group--study'
    metadata_annotation = @study.cell_metadata.first.annotation_select_value
    get render_cluster_path(accession: @study.accession, study_name: @study.url_safe_name,
                            cluster: cluster.name, annotation: annotation), xhr: true
    assert_response 200, "Did not rescue and respond 200 on invalid annotation request: #{@response.status}"

    # extract the JS variable 'loadedAnnotation' from the end of the response
    loaded_annotation = @response.parsed_body.match("var loadedAnnotation = '#{metadata_annotation}'")
    assert_not_nil loaded_annotation, "Did not find variable loadedAnnotation with correct value of #{metadata_annotation}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

end
