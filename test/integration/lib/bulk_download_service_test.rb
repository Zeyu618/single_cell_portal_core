require "test_helper"

class BulkDownloadServiceTest < ActiveSupport::TestCase

  def setup
    @user = User.find_by(email: 'testing.user.2@gmail.com')
    @random_seed = File.open(Rails.root.join('.random_seed')).read.strip
    @study = Study.find_by(name: "Test Study #{@random_seed}")
  end

  test 'should update user download quota' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    files = @study.study_files
    starting_quota = @user.daily_download_quota
    bytes_requested = files.map(&:upload_file_size).reduce(:+)
    BulkDownloadService.update_user_download_quota(user: @user, files: files)
    @user.reload
    current_quota = @user.daily_download_quota
    assert current_quota > starting_quota, "User download quota did not increase"
    assert_equal current_quota, (starting_quota + bytes_requested),
                 "User download quota did not increase by correct amount: #{current_quota} != #{starting_quota + bytes_requested}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should load requested files' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    requested_file_types = %w(Metadata Expression)
    files = BulkDownloadService.get_requested_files(file_types: requested_file_types, study_accessions: [@study.accession])
    assert_equal 2, files.size, "Did not find correct number of files, expected 2 but found #{files.size}"
    expected_files = @study.study_files.by_type(['Metadata', 'Expression Matrix']).map(&:name).sort
    found_files = files.map(&:name).sort
    assert_equal expected_files, found_files, "Did not find the correct files, expected: #{expected_files} but found #{found_files}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get requested file sizes by query' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    requested_file_types = %w(Metadata Expression)
    files_by_size = BulkDownloadService.get_requested_file_sizes_by_type(file_types: requested_file_types, study_accessions: [@study.accession])
    assert_equal 2, files_by_size.keys.size,
                 "Did not find correct number of file classes, expected 2 but found #{files_by_size.keys.size}"
    expected_response = {
        Metadata: {
            total_files: 1,
            total_bytes: @study.metadata_file.upload_file_size
        },
        Expression: {
            total_files: 1,
            total_bytes: @study.expression_matrix_files.first.upload_file_size
        }
    }.with_indifferent_access
    assert_equal expected_response, files_by_size.with_indifferent_access,
                 "Did not return correct response, expected: #{expected_response} but found #{files_by_size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  # should return curl configuration file contents
  # mock call to GCS as this is covered in API/SearchControllerTest
  test 'should generate curl configuration' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study_file = @study.metadata_file
    bucket_map = BulkDownloadService.generate_study_bucket_map([@study.accession])
    path_map = BulkDownloadService.generate_output_path_map([study_file])
    signed_url = "https://storage.googleapis.com/#{@study.bucket_id}/#{study_file.upload_file_name}"
    output_path = study_file.bulk_download_pathname
    fake_hostname = "https://localhost"
    manifest_path = "#{fake_hostname}/single_cell/api/v1/studies/#{@study.id}/manifest"

    # mock call to GCS
    mock = Minitest::Mock.new
    mock.expect :execute_gcloud_method, signed_url, [:generate_signed_url, Integer, String, String, Hash]
    FireCloudClient.stub :new, mock do
      configuration = BulkDownloadService.generate_curl_configuration(study_files: [study_file], user: @user,
                                                                      study_bucket_map: bucket_map,
                                                                      output_pathname_map: path_map,
                                                                      hostname: fake_hostname)
      mock.verify
      assert configuration.include?(signed_url), "Configuration does not include expected signed URL (#{signed_url}): #{configuration}"
      assert configuration.include?(output_path), "Configuration does not include expected output path (#{output_path}): #{configuration}"
      assert configuration.include?(manifest_path), "Configuration does not include manifest link (#{manifest_path}): #{configuration}"
    end

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  # validate each study ID and bucket_id from bucket_map
  test 'should generate map of study ids to bucket names' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    bucket_map = BulkDownloadService.generate_study_bucket_map(Study.pluck(:accession))
    bucket_map.each do |study_id, bucket_id|
      study = Study.find(study_id)
      assert study.present?, "Invalid study id: #{study_id}"
      assert_equal study.bucket_id, bucket_id, "Invalid bucket id for #{study_id}: #{study.bucket_id} != #{bucket_id}"
    end

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  # validate each study_file_id and bulk_download_pathname from output_map
  test 'should generate map of study file ids to output pathnames' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    output_map = BulkDownloadService.generate_output_path_map(StudyFile.all)
    output_map.each do |study_file_id, output_path|
      study_file = StudyFile.find(study_file_id)
      assert study_file.present?, "Invalid study_file_id: #{study_file_id}"
      assert_equal study_file.bulk_download_pathname, output_path,
                   "Invalid bulk_download_pathname for #{study_file_id}: #{study_file.bulk_download_pathname} != #{output_path}"
    end

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get list of permitted accessions' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    accessions = Study.pluck(:accession)
    permitted = BulkDownloadService.get_permitted_accessions(study_accessions: accessions, user: @user)
    assert_equal accessions.sort, permitted.sort,
                 "Did not return expected list of accessions; #{permitted} != #{accessions}"

    # add download agreement to remove study from list
    download_agreement = DownloadAgreement.new(study_id: @study.id, content: 'This is the agreement content')
    download_agreement.save!
    with_agreement = BulkDownloadService.get_permitted_accessions(study_accessions: accessions, user: @user)
    refute with_agreement.include?(@study.accession),
           "Should not have found #{@study.accession} in updated list: #{with_agreement}"

    # accept terms to restore access
    download_acceptance = DownloadAcceptance.new(email: @user.email, download_agreement: download_agreement)
    download_acceptance.save!

    final_accessions = BulkDownloadService.get_permitted_accessions(study_accessions: accessions, user: @user)
    assert_equal accessions.sort, final_accessions.sort,
                 "Did not return expected list of accessions; #{final_accessions} != #{accessions}"

    # clean up
    download_acceptance.destroy
    download_agreement.destroy
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should generate study manifest file' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    study = FactoryBot.create(:detached_study, name: "#{self.method_name}")
    raw_counts_file =  FactoryBot.create(:study_file,
      study: study,
      file_type: 'Expression Matrix',
      name: 'test_exp_validate',
      taxon_id: Taxon.new.id,
      expression_file_info: ExpressionFileInfo.new(
        units: 'raw counts',
        library_construction_protocol: 'MARS-seq',
        is_raw_counts: true
      )
    )
    study.study_files << raw_counts_file
    manifest_obj = BulkDownloadService.generate_study_manifest(study, 'localhost')
    # just test basic properties for now, we can add more once the format is finalized
    assert_equal study.name, manifest_obj[:study][:name]
    assert_equal 1, manifest_obj[:files].count
    assert_equal raw_counts_file.expression_file_info.units,
                 manifest_obj[:files][0][:units]

    study.destroy!
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
