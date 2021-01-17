class ReportsController < ApplicationController

  ###
  #
  # This controller only displays charts with information about site usage (e.g. number of studies, users, etc.)
  #
  ###

  before_action do
    authenticate_user!
    authenticate_reporter
  end

  # show summary statistics about portal studies and users
  # Calculations in this method must be done reasonably performantly to avoid server timeouts
  # This could eventually be converted to individual REST endpoints for each stat group
  def index
    # only load studies not queued for deletion
    @all_studies = Study.where(queued_for_deletion: false).pluck(:id, :created_at, :cell_count, :user_id, :public)
    @public_studies = @all_studies.select {|s| s[4]}
    @private_studies = @all_studies.select {|s| !s[4]}


    now = Time.zone.now
    one_week_ago = now - 1.weeks

    # set up local collections and labels
    users = User.all.pluck(:id, :last_sign_in_at, :current_sign_in_at, :email)
    public_label = 'Public'
    private_label = 'Private'
    study_types = [public_label, private_label]
    all_studies_label = study_types.join(' & ')

    # study distributions
    today = Date.today
    @private_study_age_dist = {private_label => @private_studies.map {|s| (today - s[1].to_date).to_i / 7}}
    if @private_study_age_dist[private_label].empty?
      @private_dist_avg = 0
    else
      @private_dist_avg = @private_study_age_dist[private_label].reduce(0, :+) / @private_study_age_dist[private_label].size.to_f
    end

    # build a hash of study_id => # of shares
    share_count_hash = Hash.new(0)
    StudyShare.pluck(:study_id).each { |id| share_count_hash[id] += 1 }
    @collab_dist = { all_studies_label => share_count_hash.values }
    @collab_dist_avg = @collab_dist[all_studies_label].sum / @collab_dist[all_studies_label].size.to_f
    @cell_dist = @all_studies.map{|s| s[2] }
    @private_cell_dist = @private_studies.map{|s| s[2] }
    @public_cell_dist = @public_studies.map{|s| s[2] }
    # calculate bin size as 10 ** two orders of magnitude less than max cells
    bin_size = 10 ** (@cell_dist.max.to_s.size - 2)
    max_cells = @cell_dist.max - @cell_dist.max % bin_size
    @cell_count_bin_dist = {public_label => {}, private_label => {}}
    0.step(max_cells, bin_size).each do |bin|
      bin_label = "#{bin}-#{bin + bin_size}"
      @cell_count_bin_dist[public_label][bin_label] = @public_studies.select {|s| s[2] >= bin && s[2] < (bin + bin_size)}.size
      @cell_count_bin_dist[private_label][bin_label] = @private_studies.select {|s| s[2] >= bin && s[2] < (bin + bin_size)}.size
    end
    @cell_avg = @cell_dist.reduce(0, :+) / @cell_dist.size.to_f

    # cells over time
    @cells_over_time = { 'All Studies' => {}, public_label => {}, private_label => {}}
    @all_studies.each do |study|
      # get date as YYYY-MM
      date = study[1].strftime("%Y-%m")
      cell_count = study[2]
      # initialize entry for that date in cumulative count
      @cells_over_time['All Studies'][date] ||= 0
      @cells_over_time['All Studies'][date] += cell_count
      # determine which bucket to add cell count into (Public/Private)
      label = study[4] ? public_label : private_label
      @cells_over_time[label][date] ||= 0
      @cells_over_time[label][date] += cell_count
      # create an empty entry at the same timepoint in the opposite bucket so we have the same number of timepoints in both
      opposite_label = label == public_label ? private_label : public_label
      @cells_over_time[opposite_label][date] ||= 0
    end
    # calculate cumulative rollups
    @cells_over_time.each do |visibility, totals|
      sum = 0
      totals.sort_by {|date, count| date}.each_with_index do |entry, index|
        if index == 0
          sum = entry.last
        else
          sum += entry.last
          @cells_over_time[visibility][entry.first] = sum
        end
      end
    end

    # user distributions
    # build a hash of user_id => study count
    user_study_hash = Hash.new(0)
    users.each {|u| user_study_hash[u[0]] = 0 }
    @all_studies.each { |s| user_study_hash[s[3]] += 1 }
    @user_study_dist = { all_studies_label => user_study_hash.values }

    user_domain_hash = Hash.new(0)
    users.each { |u| user_domain_hash[u[0]] = u[3].split('@').last }
    email_domains = user_domain_hash.values.uniq.sort
    user_study_email_dist = {}
    totals_by_domain = {}
    email_domains.each {|d| totals_by_domain[d] = 0}
    study_types.each do |study_type|
      user_study_email_dist[study_type] = {}
      if study_type == 'Public'
        studies = @public_studies
      else
        studies = @private_studies
      end
      # build a hash of user email domain => study count
      domain_counts = Hash.new(0)
      studies.map {|s| user_domain_hash[s[3]]}.each {|d| domain_counts[d] += 1 }
      user_study_email_dist[study_type] = domain_counts
      domain_counts.each {|domain, count| totals_by_domain[domain] += count }
    end
    @user_study_avg = @user_study_dist[all_studies_label].sum / @user_study_dist[all_studies_label].size.to_f
    @email_domain_avg = totals_by_domain.values.reduce(0, :+) / totals_by_domain.values.size

    # compute time-based breakdown of returning user counts
    @returning_users_by_week = {}
    user_timepoints = ReportTimePoint.where(name: 'Weekly Returning Users', :date.lte => today).order(date: :desc).take(26)
    user_timepoints.each do |timepoint|
      @returning_users_by_week[timepoint.date.to_s] = timepoint.value[:count]
    end
    # now figure out returning users since last report
    if user_timepoints.any?
      latest_date = user_timepoints.sort_by {|tp| tp.date}.last.date
      if latest_date < today
        next_period = latest_date + 1.week
        @returning_users_by_week[next_period.to_s] = users.select {|user| user[1] >= latest_date || user[2] >= latest_date }.size
      end
    else
      latest_date = today - 1.week
      @returning_users_by_week[today.to_s] = users.select {|user| user[1] && (user[1] >= latest_date || user[2] >= latest_date) }.size
    end

    # sort domain breakdowns by totals to order plot
    sorted_domains = totals_by_domain.sort_by {|k,v| v}.reverse.map(&:first)
    @sorted_email_domain_dist = {}
    study_types.each do |study_type|
      @sorted_email_domain_dist[study_type] = {}
      sorted_domains.each do |domain|
        @sorted_email_domain_dist[study_type][domain] = user_study_email_dist[study_type][domain]
      end
    end

    # get pipeline statistics
    @has_pipeline_stats = false
    @pipeline_success = {}
    @pipeline_fail = {}
    # report on analysis submission stats (last 6 months, submitted from portal, completed workflows only)
    report_timeframe = now - 6.months
    submissions = AnalysisSubmission.where(:submitted_on.gte => report_timeframe, :status.in => ['Succeeded', 'Failed'],
                                           submitted_from_portal: true)
    @pipeline_dates = submissions.map {|s| s.submitted_on.strftime('%Y-%m')}.uniq # find all existing date periods
    @starting_counts = @pipeline_dates.size.times.map {0} # initialize counts to zero
    submissions.each do |analysis|
      @has_pipeline_stats = true
      pipeline_name = analysis.analysis_name
      date_bracket = analysis.submitted_on.strftime('%Y-%m')
      @pipeline_success[pipeline_name] ||= Hash[@pipeline_dates.zip(@starting_counts)] # create hash of 0s for all dates
      @pipeline_fail[pipeline_name] ||= Hash[@pipeline_dates.zip(@starting_counts)] # create hash of 0s for all dates
      if analysis.status == 'Succeeded'
        @pipeline_success[pipeline_name][date_bracket] += 1
      else
        @pipeline_fail[pipeline_name][date_bracket] += 1
      end
    end
    max_success_count = @pipeline_success.values.map(&:values).flatten.max || 0
    max_fail_count = @pipeline_fail.values.map(&:values).flatten.max || 0
    @pipeline_success_range = [0, (max_success_count * 1.1)] # add 10% to range for annotations
    @pipeline_fail_range = [0, (max_fail_count * 1.1)] # add 10% to range for annotations
  end

  def report_request

  end

  # send a message to the site administrator requesting a new report plot
  def submit_report_request
    @subject = report_request_params[:subject]
    @requester = report_request_params[:requester]
    @message = report_request_params[:message]

    SingleCellMailer.admin_notification(@subject, @requestor, @message).deliver_now
    redirect_to reports_path, notice: 'Your request has been submitted.' and return
  end

  def export_submission_report
    if current_user.admin?
      @submission_stats = []
      AnalysisSubmission.order(:submitted_on => :asc).each do |analysis|
        @submission_stats << {submitter: analysis.submitter, analysis: analysis.analysis_name, status: analysis.status,
                              submitted_on: analysis.submitted_on, completed_on: analysis.completed_on,
                              firecloud_workspace: "#{analysis.firecloud_project}/#{analysis.firecloud_workspace}",
                              study_info_url: study_url(id: analysis.study_id)}
      end
      filename = "analysis_submissions_#{Date.today.strftime('%F')}.txt"
      report_headers = %w(email analysis status submission_date completion_date firecloud_workspace study_info_url).join("\t")
      report_data = @submission_stats.map {|sub| sub.values.join("\t")}.join("\n")
      send_data [report_headers, report_data].join("\n"), filename: filename
    else
      alert = 'You do not have permission to perform that action'
      respond_to do |format|
        format.html {redirect_to reports_path, alert: alert and return}
        format.js {render js: "alert('#{alert}');"}
        format.json {render json: {error: alert}, status: 403}
      end
    end
  end

  private

  def report_request_params
    params.require(:report_request).permit(:subject, :requester, :message)
  end
end
