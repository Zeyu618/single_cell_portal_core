class ProfilesController < ApplicationController

  ##
  #
  # ProfilesController: controller to allow users to manage certain aspects of their user account
  # since user accounts map to Google profiles, we cannot alter anything about the source profile
  #
  ##

  before_action :set_user
  before_filter do
    authenticate_user!
    check_access_settings
  end

  def show
    @study_shares = StudyShare.where(email: @user.email)
    @studies = Study.where(user_id: @user.id)
    @profile_info = {}
    begin
      user_client = FireCloudClient.new(current_user, FireCloudClient::PORTAL_NAMESPACE)
      profile = user_client.get_profile
      profile['keyValuePairs'].each do |attribute|
        @profile_info[attribute['key']] = attribute['value']
      end
    rescue => e
      logger.info "#{Time.now}: unable to retrieve FireCloud profile for #{current_user.email}: #{e.message}"
    end
  end

  def update
    if @user.update(user_params)
      @notice = 'Admin email subscription update successfully recorded.'
    else
      @alert = "Unable to save admin email subscription settings: #{@user.errors.map(&:full_messages).join(', ')}"
    end
  end

  def update_study_subscription
    @study = Study.find(params[:study_id])
    update = study_params[:default_options][:deliver_emails] == 'true'
    opts = @study.default_options
    if @study.update(default_options: opts.merge(deliver_emails: update))
      @notice = 'Study email subscription update successfully recorded.'
    else
      @alert = "Unable to save study email subscription settings: #{@share.errors.map(&:full_messages).join(', ')}"
    end
  end

  def update_share_subscription
    @share = StudyShare.find(params[:study_share_id])
    update = study_share_params[:deliver_emails] == 'true'
    if @share.update(deliver_emails: update)
      @notice = 'Study email subscription update successfully recorded.'
    else
      @alert = "Unable to save study email subscription settings: #{@share.errors.map(&:full_messages).join(', ')}"
    end
  end

  def update_firecloud_profile
    begin
      user_client = FireCloudClient.new(current_user, FireCloudClient::PORTAL_NAMESPACE)
      user_client.set_profile(profile_params)
      # log that user has registered so we can use this elsewhere
      if !current_user.registered_for_firecloud
        current_user.update(registered_for_firecloud: true)
      end
      @notice = "Your FireCloud profile has been successfully updated."
      # now check if user is part of 'all-portal' user group
      current_user.add_to_portal_user_group
    rescue => e
      logger.info "#{Time.now}: unable to update FireCloud profile for #{current_user.email}: #{e.message}"
      @alert = "An error occurred when trying to update your FireCloud profile: #{e.message}"
    end
  end

  private

  # set the requested user account
  def set_user
    @user = User.find(params[:id])
  end

  # make sure the current user is the same as the requested profile
  def check_access_settings
    if current_user.email != @user.email
      redirect_to merge_default_redirect_params(site_path, scpbr: params[:scpbr]), alert: 'You do not have permission to perform that action.' and return
    end
  end

  def user_params
    params.require(:user).permit(:admin_email_delivery)
  end

  def study_share_params
    params.require(:study_share).permit(:deliver_emails)
  end

  def study_params
    params.require(:study).permit(:default_options => [:deliver_emails])
  end

  # parameters for service account profile
  def profile_params
    params.require(:firecloud_profile).permit(:contactEmail, :email, :firstName, :lastName, :institute, :institutionalProgram,
                                            :nonProfitStatus, :pi, :programLocationCity, :programLocationState,
                                            :programLocationCountry, :title)
  end
end
