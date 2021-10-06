require 'test_helper'

class FeatureAnnouncementTest< ActiveSupport::TestCase
  include Minitest::Hooks
  include TestInstrumentor
  include SelfCleaningSuite

  before(:all) do
    @feature_announcement = FeatureAnnouncement.create(
      title: 'Amazing New Feature',
      content: '<p>This is the content.</p>',
      doc_link: 'https://singlecell.zendesk.com/hc/en-us',
      published: true,
      archived: false
    )
    @today = Date.today.in_time_zone.strftime('%F')
  end

  after(:all) do
    FeatureAnnouncement.destroy_all
  end

  teardown do
    FeatureAnnouncement.update_all(published: true, archived: false)
  end

  test 'should set slug on save' do
    assert_equal "#{@today}-amazing-new-feature", @feature_announcement.slug
    @feature_announcement.update(title: 'Announcing a New Feature!!')
    @feature_announcement.reload
    assert_equal "#{@today}-announcing-a-new-feature", @feature_announcement.slug
  end

  test 'should determine if there are latest features' do
    assert FeatureAnnouncement.latest_features?
    FeatureAnnouncement.update_all(published: false)
    assert_not FeatureAnnouncement.latest_features?
  end

  test 'should determine if there are archived features' do
    assert_not FeatureAnnouncement.archived_features?
    FeatureAnnouncement.update_all(archived: true)
    assert FeatureAnnouncement.archived_features?
  end

  test 'should track dates when feature is published/archived' do
    today = Time.zone.today
    feature = FeatureAnnouncement.create(
      title: 'History Test',
      content: '<p>This is the content.</p>',
      doc_link: 'https://singlecell.zendesk.com/hc/en-us',
      published: false,
      archived: false
    )
    assert_nil feature.history[:published]
    assert_nil feature.history[:archived]
    feature.update(published: true, archived: true)
    assert_equal today, feature.history[:published]
    assert_equal today, feature.history[:archived]
    feature.update(published: false, archived: false)
    assert_nil feature.history[:published]
    assert_nil feature.history[:archived]
  end
end
