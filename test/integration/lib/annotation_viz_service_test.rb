require "test_helper"

class AnnotationVizServiceTest < ActiveSupport::TestCase
  include Minitest::Hooks
  include SelfCleaningSuite
  include TestInstrumentor

  before(:all) do
    @user = FactoryBot.create(:user, test_array: @@users_to_clean)
    @basic_study = FactoryBot.create(:detached_study, name_prefix: 'Basic Viz', test_array: @@studies_to_clean)
    @basic_study_cluster_file = FactoryBot.create(:cluster_file,
                                              name: 'cluster_1.txt', study: @basic_study,
                                              annotation_input: [
                                                  {name: 'Category', type: 'group', values: ['bar', 'bar', 'baz']},
                                                  {name: 'Intensity', type: 'numeric', values: [1.1, 2.2, 3.3]}
                                              ])
    @basic_study_cluster_file2 = FactoryBot.create(:cluster_file,
                                              name: 'cluster_2.txt', study: @basic_study,
                                              annotation_input: [
                                                  {name: 'Fizziness', type: 'group', values: ['high', 'low', 'medium']},
                                                  {name: 'Buzziness', type: 'group', values: ['large', 'medium', 'small']}
                                              ])
    @basic_study_exp_file = FactoryBot.create(:study_file,
                                                  name: 'dense.txt',
                                                  file_type: 'Expression Matrix',
                                                  study: @basic_study)

    @study_metadata_file = FactoryBot.create(:metadata_file,
                                             name: 'metadata.txt', study: @basic_study,
                                             annotation_input: [
                                                 {name: 'species', type: 'group', values: ['dog', 'cat', 'dog']},
                                                 {name: 'disease', type: 'group', values: ['none', 'none', 'measles']}
                                             ])

  end


  test 'gets the default annotation when no annotation name is specified' do
    annotation = AnnotationVizService.get_selected_annotation(@basic_study, nil, nil, nil, nil)
    assert_equal 'Category', annotation[:name]
    assert_equal  ['bar', 'baz'], annotation[:values]

    annotation = AnnotationVizService.get_selected_annotation(@basic_study, nil, nil, nil, 'study')
    assert_equal 'species', annotation[:name]
    assert_equal  ['dog', 'cat'], annotation[:values]

    fizz_cluster = @basic_study.cluster_groups.find_by(name: 'cluster_2.txt')
    annotation = AnnotationVizService.get_selected_annotation(@basic_study, fizz_cluster, nil, nil, nil)
    assert_equal 'Fizziness', annotation[:name]
    assert_equal  ['high', 'low', 'medium'], annotation[:values]

    @basic_study.update!(default_options: {
        cluster: 'cluster_1.txt',
        annotation: 'species--group--study'
    })
    annotation = AnnotationVizService.get_selected_annotation(@basic_study, nil, nil, nil, nil)
    assert_equal 'species', annotation[:name]
    assert_equal ['dog', 'cat'], annotation[:values]
  end

  test 'can get annotations by name and scope' do
    annotation = AnnotationVizService.get_selected_annotation(@basic_study, nil, 'disease', 'group', 'study')
    assert_equal 'disease', annotation[:name]
    assert_equal  ['none', 'measles'], annotation[:values]

    cluster = @basic_study.cluster_groups.first
    annotation = AnnotationVizService.get_selected_annotation(@basic_study, cluster, 'Intensity', 'numeric', 'cluster')
    assert_equal 'Intensity', annotation[:name]
    assert_equal  [1.1, 2.2, 3.3], annotation[:values]
  end

  test 'returns first study/cluster annotation if no matching annotation is found' do
    annotation = AnnotationVizService.get_selected_annotation(@basic_study, nil, 'foobar', 'group', 'study')
    assert_equal 'species', annotation[:name]
    cluster = @basic_study.cluster_groups.first
    annotation = AnnotationVizService.get_selected_annotation(@basic_study, cluster, 'foobar', 'group', 'cluster')
    assert_equal 'Category', annotation[:name]
  end
end
