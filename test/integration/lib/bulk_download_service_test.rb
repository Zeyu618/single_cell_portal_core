require "test_helper"
require 'csv'
require "bulk_download_helper"

class BulkDownloadServiceTest < ActiveSupport::TestCase
  include Minitest::Hooks
  include TestInstrumentor

  def setup
    @user = User.find_by(email: 'testing.user.2@gmail.com')
    @random_seed = File.open(Rails.root.join('.random_seed')).read.strip
    @study = Study.find_by(name: "Testing Study #{@random_seed}")
  end

  test 'should update user download quota' do
    files = @study.study_files
    starting_quota = @user.daily_download_quota
    directory = @study.directory_listings.first
    bytes_requested = files.map(&:upload_file_size).reduce(:+) + directory.total_bytes
    BulkDownloadService.update_user_download_quota(user: @user, files: files, directories: @study.directory_listings)
    @user.reload
    current_quota = @user.daily_download_quota
    assert current_quota > starting_quota, "User download quota did not increase"
    assert_equal current_quota, (starting_quota + bytes_requested),
                 "User download quota did not increase by correct amount: #{current_quota} != #{starting_quota + bytes_requested}"
  end

  test 'should load requested files' do
    requested_file_types = %w(Metadata Expression)
    files = BulkDownloadService.get_requested_files(file_types: requested_file_types, study_accessions: [@study.accession])
    expected_files = @study.study_files.where(:file_type.in => ['Metadata', /Matrix/, /10X/])
    expected_count = expected_files.size
    assert_equal expected_count, files.size, "Did not find correct number of files, expected #{expected_count} but found #{files.size}"
    expected_filenames = expected_files.map(&:name).sort
    found_files = files.map(&:name).sort
    assert_equal expected_filenames, found_files, "Did not find the correct files, expected: #{expected_files} but found #{found_files}"
  end

  test 'should get requested directories' do
    files = BulkDownloadService.get_requested_directory_files(@study.directory_listings)
    expected_files = @study.directory_listings.first.files
    expected_count = expected_files.size
    assert_equal expected_count, files.size, "Did not find correct number of files, expected #{expected_count} but found #{files.size}"
    expected_filenames = expected_files.map {|f| f[:name]}.sort
    found_files = files.map {|f| f[:name]}.sort
    assert_equal expected_filenames, found_files, "Did not find the correct files, expected: #{expected_files} but found #{found_files}"
  end

  test 'should get requested file sizes by query' do
    file_listing = BulkDownloadService.get_download_info([@study.accession])
    expected_info = [{
      :name=>"Testing Study 12cf809a1e48cf84c369f4895a2a4411",
      :accession=>"SCP15",
      :description=>"This is the test study.",
      :study_files=>[{
        :name=>"expression_matrix_example.txt",
        :id=>"60734561cc7ba00d899d03d4",
        :file_type=>"Expression Matrix",
        :upload_file_size=>1071
      },{
        :name=>"metadata_example.txt",
        :id=>"60734563cc7ba00d899d03d6",
        :file_type=>"Metadata",
        :upload_file_size=>10147
      },{
        :name=>"cluster_example.txt",
        :id=>"60734564cc7ba00d899d03d8",
        :file_type=>"Cluster",
        :upload_file_size=>680
      }]
    }]
    assert_equal 1, expected_info.count
    assert expected_info[0][:name].starts_with?('Testing Study')
    assert_equal 3, expected_info[0][:study_files].count
    assert_equal ["Expression Matrix", "Metadata", "Cluster"], expected_info[0][:study_files].map{|s| s[:file_type]}
    assert_equal [1071, 10147, 680], expected_info[0][:study_files].map{|s| s[:upload_file_size]}
  end

  test 'should get requested directory sizes' do
    dir_files_by_size = BulkDownloadService.get_requested_directory_sizes(@study.directory_listings)
    directory = @study.directory_listings.first
    expected_files = directory.files
    returned_files = get_file_count_from_response(dir_files_by_size)
    assert_equal expected_files.size, returned_files,
                 "Did not find correct number of directory files, expected #{expected_files.size} but found #{returned_files}"
    expected_bytes = directory.total_bytes
    returned_bytes = get_file_size_from_response(dir_files_by_size)
    assert_equal expected_bytes, returned_bytes,
                 "Did not find correct total_bytes for directory, expected #{expected_bytes} but found #{returned_bytes}"
  end

  # should return curl configuration file contents
  # mock call to GCS as this is covered in API/SearchControllerTest
  test 'should generate curl configuration' do
    study_file = @study.metadata_file
    directory = @study.directory_listings.first
    bucket_map = BulkDownloadService.generate_study_bucket_map([@study.accession])
    path_map = BulkDownloadService.generate_output_path_map([study_file], [directory])
    directory_file_list = BulkDownloadService.get_requested_directory_files([directory])
    signed_url = "https://storage.googleapis.com/#{@study.bucket_id}/#{study_file.upload_file_name}"
    output_path = study_file.bulk_download_pathname
    directory_file = directory.files.sample
    dir_signed_url = "https://storage.googleapis.com/#{@study.bucket_id}/#{directory_file[:name]}"
    dir_output_path = directory.bulk_download_pathname(directory_file)
    manifest_path = "#{RequestUtils.get_base_url}/single_cell/api/v1/studies/#{@study.id}/manifest"

    # mock call to GCS
    mock = Minitest::Mock.new
    mock.expect :execute_gcloud_method, signed_url, [:generate_signed_url, Integer, String, String, Hash]
    mock.expect :execute_gcloud_method, dir_signed_url, [:generate_signed_url, Integer, String, String, Hash]
    FireCloudClient.stub :new, mock do
      configuration = BulkDownloadService.generate_curl_configuration(study_files: [study_file], user: @user,
                                                                      directory_files: directory_file_list,
                                                                      study_bucket_map: bucket_map,
                                                                      output_pathname_map: path_map)
      mock.verify
      assert configuration.include?(signed_url), "Configuration does not include expected signed URL (#{signed_url}): #{configuration}"
      assert configuration.include?(output_path), "Configuration does not include expected output path (#{output_path}): #{configuration}"
      assert configuration.include?(dir_signed_url), "Configuration does not include expected directory signed URL (#{dir_signed_url}): #{configuration}"
      assert configuration.include?(dir_output_path), "Configuration does not include expected directory output path (#{dir_output_path}): #{configuration}"
      assert configuration.include?(manifest_path), "Configuration does not include manifest link (#{manifest_path}): #{configuration}"
    end
  end

  # validate each study ID and bucket_id from bucket_map
  test 'should generate map of study ids to bucket names' do
    bucket_map = BulkDownloadService.generate_study_bucket_map(Study.pluck(:accession))
    bucket_map.each do |study_id, bucket_id|
      study = Study.find(study_id)
      assert study.present?, "Invalid study id: #{study_id}"
      assert_equal study.bucket_id, bucket_id, "Invalid bucket id for #{study_id}: #{study.bucket_id} != #{bucket_id}"
    end
  end

  # validate each study_file_id and bulk_download_pathname from output_map
  test 'should generate map of study file ids to output pathnames' do
    files = @study.study_files
    directories = @study.directory_listings
    output_map = BulkDownloadService.generate_output_path_map(files, directories)
    files.each do |file|
      expected_output_path = file.bulk_download_pathname
      output_path = output_map[file.id.to_s]
      assert_equal expected_output_path, output_path,
                   "Invalid bulk_download_pathname for #{file.id}: #{expected_output_path} != #{output_path}"
    end
    directories.each do |directory|
      directory.files.each do |file|
        expected_output_path = directory.bulk_download_pathname(file)
        output_path = output_map[file[:name]]
        assert_equal expected_output_path, output_path,
                     "Invalid bulk_download_pathname for directory file #{directory[:name]}/#{file[:name]}: #{expected_output_path} != #{output_path}"
      end
    end
  end

  test 'should get list of permitted accessions' do
    accessions = Study.viewable(@user).pluck(:accession)
    accessions_by_permission = BulkDownloadService.get_permitted_accessions(study_accessions: accessions, user: @user)
    assert_equal accessions.sort, accessions_by_permission[:permitted].sort,
                 "Did not return expected list of accessions; #{accessions_by_permission[:permitted]} != #{accessions}"

    # add download agreement to remove study from list
    download_agreement = DownloadAgreement.new(study_id: @study.id, content: 'This is the agreement content')
    download_agreement.save!
    accessions_by_permission = BulkDownloadService.get_permitted_accessions(study_accessions: accessions, user: @user)
    assert accessions_by_permission[:lacks_acceptance].include?(@study.accession),
           "Should have listed #{@study.accession} in lacks_acceptance list"
    refute accessions_by_permission[:permitted].include?(@study.accession),
           "Should not have listed #{@study.accession} in permitted list"

    # accept terms to restore access
    download_acceptance = DownloadAcceptance.new(email: @user.email, download_agreement: download_agreement)
    download_acceptance.save!

    accessions_by_permission = BulkDownloadService.get_permitted_accessions(study_accessions: accessions, user: @user)
    assert_equal accessions.sort, accessions_by_permission[:permitted].sort,
                 "Did not return expected list of accessions; #{accessions_by_permission[:permitted]} != #{accessions}"

    # clean up
    download_acceptance.destroy
    download_agreement.destroy
  end

  test 'should generate study manifest file' do
    study = FactoryBot.create(:detached_study, name_prefix: "#{self.method_name}")
    raw_counts_file =  FactoryBot.create(:study_file,
      study: study,
      file_type: 'Expression Matrix',
      name: 'test_exp_validate.tsv',
      taxon_id: Taxon.new.id,
      expression_file_info: ExpressionFileInfo.new(
        units: 'raw counts',
        library_preparation_protocol: 'MARS-seq',
        biosample_input_type: 'Whole cell',
        modality: 'Transcriptomic: targeted',
        is_raw_counts: true
      )
    )

    metadata_file =  FactoryBot.create(:study_file,
      study: study,
      file_type: 'Metadata',
      name: 'metadata2.tsv'
    )

    manifest_obj = BulkDownloadService.generate_study_manifest(study)
    # just test basic properties for now, we can add more once the format is finalized
    assert_equal study.name, manifest_obj[:study][:name]
    assert_equal 2, manifest_obj[:files].count

    tsv_string = BulkDownloadService.generate_study_files_tsv(study)
    tsv = ::CSV.new(tsv_string, col_sep: "\t", headers: true)
    rows = tsv.read
    assert_equal 2, rows.count
    raw_count_row = rows.find {|r| r['filename'] == 'test_exp_validate.tsv'}
    assert_equal "true", raw_count_row['is_raw_counts']

    study.destroy!
  end
end
