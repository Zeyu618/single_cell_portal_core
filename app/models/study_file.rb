class StudyFile
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip
  include Rails.application.routes.url_helpers

  # constants, used for statuses and file types
  STUDY_FILE_TYPES = ['Cluster', 'Expression Matrix', 'Gene List', 'Metadata', 'Fastq', 'Documentation', 'Other']
  PARSEABLE_TYPES = ['Cluster', 'Expression Matrix', 'Gene List', 'Metadata']
  UPLOAD_STATUSES = %w(new uploading uploaded)
  PARSE_STATUSES = %w(unparsed parsing parsed)

  # associations
  belongs_to :study, index: true
  has_many :cluster_groups, dependent: :destroy
  has_many :expression_scores, dependent: :destroy
  has_many :precomputed_scores, dependent: :destroy
  has_many :temp_file_downloads
  has_many :study_metadatas, dependent: :destroy

  # field definitions
  field :name, type: String
  field :path, type: String
  field :description, type: String
  field :file_type, type: String
  field :cluster_type, type: String
  field :url_safe_name, type: String
  field :status, type: String
  field :parse_status, type: String, default: 'unparsed'
  field :human_fastq_url, type: String
  field :human_data, type: Boolean, default: false
  field :x_axis_label, type: String, default: ''
  field :y_axis_label, type: String, default: ''
  field :z_axis_label, type: String, default: ''
  field :x_axis_min, type: Integer
  field :x_axis_max, type: Integer
  field :y_axis_min, type: Integer
  field :y_axis_max, type: Integer
  field :z_axis_min, type: Integer
  field :z_axis_max, type: Integer

  # callbacks
  before_create   :make_data_dir
  before_create   :set_file_name_and_url_safe_name
  after_save      :check_public?, :update_cell_count, :set_cluster_group_ranges
  before_destroy  :remove_public_symlink

  has_mongoid_attached_file :upload,
                            :path => ":rails_root/data/:url_safe_name/:filename",
                            :url => "/single_cell/data/:url_safe_name/:filename"

  # turning off validation to allow any kind of data file to be uploaded
  do_not_validate_attachment_file_type :upload

  validates_uniqueness_of :upload_file_name, scope: :study_id, unless: Proc.new {|f| f.human_data?}

  Paperclip.interpolates :url_safe_name do |attachment, style|
    attachment.instance.url_safe_name
  end

  # return public url if study is public, otherwise redirect to create templink download url
  def download_path
    if self.upload_file_name.nil?
      self.human_fastq_url
    else
      if self.study.public?
        self.upload.url
      else
        download_private_file_path(self.study.url_safe_name, self.upload_file_name)
      end
    end
  end

  # JSON response for jQuery uploader
  def to_jq_upload(error=nil)
    {
        '_id' => self._id,
        'name' => read_attribute(:upload_file_name),
        'size' => read_attribute(:upload_file_size),
        'url' => download_path,
        'delete_url' => delete_study_file_study_path(self.study._id, self._id),
        'delete_type' => "DELETE"
    }
  end

  def parseable?
    PARSEABLE_TYPES.include?(self.file_type)
  end

  def parsed?
    self.parse_status == 'parsed'
  end

  # return an integer percentage of the parsing status
  def percent_parsed
    (self.bytes_parsed / self.upload_file_size.to_f * 100).floor
  end

  # file type as a css class
  def file_type_class
    self.file_type.downcase.split.join('-') + '-file'
  end

  # return path to a file's 'public data' path (which will be a symlink to data dir)
  def public_data_path
    File.join(self.study.data_public_path, self.upload_file_name)
  end

  # single-use method to set data_dir for existing study_files
  def self.set_data_dir
    self.all.each do |study_file|
      if study_file.data_dir.nil?
        study_file.update(data_dir: study_file.study.data_dir)
        puts "Updated #{study_file.upload_file_name} with data_dir #{study_file.data_dir}"
      end
    end
    true
  end

  # convert all domain ranges from floats to integers
  def convert_all_ranges
    if self.file_type == 'Cluster'
      required_vals = 4
      domain = {
          x_axis_min: self.x_axis_min.to_i == 0 ? nil : self.x_axis_min.to_i,
          x_axis_max: self.x_axis_max.to_i == 0 ? nil : self.x_axis_max.to_i,
          y_axis_min: self.y_axis_min.to_i == 0 ? nil : self.y_axis_min.to_i,
          y_axis_max: self.y_axis_max.to_i == 0 ? nil : self.y_axis_max.to_i
      }
      empty_domain = {
          x_axis_min: nil,
          x_axis_max: nil,
          y_axis_min: nil,
          y_axis_max: nil
      }
      if self.cluster_groups.first.is_3d?
        domain[:z_axis_min] = self.z_axis_min.to_i == 0 ? nil : self.z_axis_min.to_i
        domain[:z_axis_max] = self.z_axis_max.to_i == 0 ? nil : self.z_axis_max.to_i
        empty_domain[:z_axis_min] = nil
        empty_domain[:z_axis_max] = nil
        required_vals = 6
      end
      # need to clear out domain first to force persistence
      self.update(empty_domain)
      if required_vals == domain.values.compact.size
        self.update(domain)
      end
    end
  end

  private

  def make_data_dir
    data_dir = Rails.root.join('data', self.study.url_safe_name)
    unless Dir.exist?(data_dir)
      FileUtils.mkdir_p(data_dir)
    end
  end

  # set filename and construct url safe name from study
  def set_file_name_and_url_safe_name
    if self.upload_file_name.nil?
      self.status = 'uploaded'
      if self.name.nil?
        self.name = ''
      end
    elsif (self.name.nil? || self.name.blank?) || (!self.new_record? && self.upload_file_name != self.name)
      self.name = self.upload_file_name
    end
    self.url_safe_name = self.study.url_safe_name
  end

  # add symlink if study is public and doesn't already exist
  def check_public?
    unless self.upload_file_name.nil?
      if self.study.public? && self.status == 'uploaded' && !File.exists?(self.public_data_path)
        FileUtils.ln_sf(self.upload.path, self.public_data_path)
      end
    end
  end

  # clean up any symlinks before deleting a study file
  def remove_public_symlink
    unless self.upload_file_name.nil?
      if self.study.public?
        FileUtils.rm_f(self.public_data_path)
      end
    end
  end

  # update a study's cell count if uploading an expression matrix or cluster assignment file
  def update_cell_count
    if ['Metadata', 'Expression Matrix'].include?(self.file_type) && self.status == 'uploaded' && self.parsed?
      study = self.study
      study.set_cell_count
    end
  end

  # set ranges for cluster_groups if necessary
  def set_cluster_group_ranges
    if self.file_type == 'Cluster' && self.cluster_groups.any?
      cluster = self.cluster_groups.first
      # check if range values are present and set accordingly
      if !self.x_axis_min.nil? && !self.x_axis_max.nil? && !self.y_axis_min.nil? && !self.y_axis_max.nil?
        domain_ranges = {
            x: [self.x_axis_min, self.x_axis_max],
            y: [self.y_axis_min, self.y_axis_max]
        }
        if !self.z_axis_min.nil? && !self.z_axis_max.nil?
          domain_ranges[:z] = [self.z_axis_min, self.z_axis_max]
        end
        cluster.update(domain_ranges: domain_ranges)
      else
        # either user has not supplied ranges or is deleting them, so clear entry for cluster_group
        cluster.update(domain_ranges: nil)
      end
    end
  end
end
