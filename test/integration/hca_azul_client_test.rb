require 'test_helper'

class HcaAzulClientTest < ActiveSupport::TestCase
  include Minitest::Hooks
  include TestInstrumentor

  before(:all) do
    @hca_azul_client = ApplicationController.hca_azul_client
    @project_id = 'c1a9a93d-d9de-4e65-9619-a9cec1052eaa'
  end

  test 'should instantiate client' do
    client = HcaAzulClient.new
    assert_equal HcaAzulClient::BASE_URL, client.api_root
  end

  test 'should get HCA metadata tsv link' do
    manifest_info = @hca_azul_client.get_project_manifest_link('dcp6', @project_id)
    assert manifest_info.present?
    assert_equal 302, manifest_info['Status']
    # make GET on manifest URL and assert contents are HCA metadata
    manifest_response = RestClient.get manifest_info['Location']
    assert_equal 200, manifest_response.code
    raw_manifest = manifest_response.body.split("\r\n")
    headers = raw_manifest.first.split("\t")
    project_id_header = 'project.provenance.document_id'
    assert headers.include? project_id_header
    project_idx = headers.index(project_id_header)
    data_row = raw_manifest.sample.split("\t")
    assert_equal @project_id, data_row[project_idx]
  end

  test 'should format object for query string' do
    query_object = { 'foo' => { 'bar' => 'baz' } }
    expected_response = '%7B%22foo%22%3A%7B%22bar%22%3A%22baz%22%7D%7D'
    formatted_query = @hca_azul_client.format_hash_as_query_string(query_object)
    assert_equal expected_response, formatted_query
    # assert we can get back to original object, but as JSON
    query_as_json = CGI.unescape(formatted_query)
    assert_equal query_object.to_json, query_as_json
  end
end
