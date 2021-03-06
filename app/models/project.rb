require 'will_paginate/array'

class Project < ActiveRecord::Base

  # class constants, integer so as to allow for more states in the future
  UNFINISHED = 1
  FINISHED = 2

  # class constants, for new/edit page of each project
  SECTORS = ["Animals", "Art", "Community", "Crime and safety", "Disabilities", "Disaster relief",
             "Drug abuse", "Economic development", "Education", "Environment", "Family", "Health",
             "Housing", "Human rights", "Hunger relief", "Immigration", "Legal assistance", "LGBT", "Library", "Media", 
             "Microcredit", "Philanthropy", "Policy", "Poverty relief", "Religion", "Research/science",
             "Elderly", "Sports and recreation", "Technology", "Veterans", "Women", "Youth", 
             "Other"]
  PROJECT_TYPES = ["Database", "Design", "Mobile", "Web App", "Other"]

  extend FriendlyId
  friendly_id :title, use: :slugged

  belongs_to :client
  has_and_belongs_to_many :organizations

  attr_accessible :github_site, :application_site#, :as => [:default, :admin, :owner]
  attr_accessible :questions, :title, :state#, :as => [ :owner, :admin ]
  attr_accessible :problem, :short_description, :long_description#, :as => [ :owner, :admin ]
  attr_accessible :approved, :as => :admin
  attr_accessible :admin_note, :as => :admin
  attr_accessor :project_params, :org_params
  attr_accessible :organization
  attr_accessible :project_type, :sector

  attr_accessible :user_id, :as=>:admin

  validates :title, :presence => true
  # validates :title, :mission_statement, :length => { :minimum => 4 }
  validates :title, :github_site, :application_site, :uniqueness => true, :allow_blank => true

  # validate URLs
  validates :github_site, :allow_blank => true, :format => /(((?:\/[\+~%\/.\w-_]*)?\??(?:[-\+=&;%@.\w_]*)#?(?:[\w]*))?)/ #simplified version
 # :company_site,

  #/((([A-Za-z]{3,9}:(?:\/\/)?)(?:[-;:&=\+\$,\w]+@)?[A-Za-z0-9.-]+|(?:www.|[-;:&=\+\$,\w]+@)[A-Za-z0-9.-]+)((?:\/[\+~%\/.\w-_]*)?\??(?:[-\+=&;%@.\w_]*)#?(?:[\w]*))?)/ # regex from http://blog.mattheworiordan.com/post/13174566389/url-regular-expression-for-links-with-or-without-the

  # method from StackOverflow (http://stackoverflow.com/questions/7167895/whats-a-good-way-to-validate-links-urls-in-rails-3)

  # validate emails, regex from StackOverflow (http://stackoverflow.com/questions/201323/using-a-regular-expression-to-validate-an-email-address)
  # validates_format_of :contact_email, :with => /^[_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,4})$/

  serialize :questions, Hash
  before_save :merge_questions
  # mount_uploader :photo, PhotoUploader

  scope :is_public, lambda {
    join = Project.joins(:organizations)
    # needed to avoid bug that doesn't identify public projects if all of them are public
    # known bug in ActiveRecord: http://stackoverflow.com/questions/12946004/issue-when-retrieving-records-with-empty-array
    if join.empty?
      join = [0]
    end
    Project.where("id not in (?)", join)
  }
  scope :is_private, lambda { Project.joins(:organizations) }

  scope :by_title, lambda { |search_string|
    if not search_string.empty?
      where('title like ?', "%#{search_string}%")
    end
  }

  scope :by_organization, lambda { |org|
     if not org.empty?
       joins(:client).where('clients.company_name like ?', "%#{org}%")
     end
  }

  scope :is_nonprofit, lambda { |is_nonprofit|
    if is_nonprofit
      joins(:client).where(:clients => {:nonprofit => is_nonprofit})
    end
  }

  scope :is_forprofit, lambda { |is_nonprofit|
    if is_nonprofit
      joins(:client).where(:clients => {:nonprofit => false})
    end
  }

  scope :is_five_01c3, lambda { |is_five_01c3|
    if is_five_01c3
      joins(:client).where(:clients => {:five_01c3 => is_five_01c3})
    end
  }

  scope :by_title_organization, lambda {|search|
    # project = Project.arel_table
    if search
      by_organization(search)
    end
    # where(project[:title].matches("%#{search}%").or(project.client[:company_name].matches("%#{search}%"))) if search
  }

  scope :is_finished, lambda { |is_finished|
    where(:state => Project::FINISHED) if is_finished
  }

  def self.search(params, admin)
    # if admin
      initial = Project.is_nonprofit(params.has_key?('nonprofit'))
      .is_five_01c3(params.has_key?('five_01c3'))
      .is_forprofit(params.has_key?('forprofit'))
      .is_finished(params['state'])

      initial.by_organization(params['search_string']).push(initial.by_title(params['search_string'])).flatten.uniq
    # else
    #   Project.where(:approved => true)
    #   .is_nonprofit(params.has_key?('nonprofit'))
    #   .is_five_01c3(params.has_key?('five_01c3'))
    #   .is_forprofit(params.has_key?('forprofit'))
    #   .by_title_organization(params['search_string'])
    #   .is_finished(params['state'])
    # end
  end

  def merge_questions
    updated_questions = questions.blank? ? {} : questions
    if project_questions != nil
      project_questions.each do |q|
        question_key = Project.question_key(q)
        question = self.send(question_key)
        updated_questions[question_key] = question unless questions[question_key] == question or question.nil?
      end
      self.questions = updated_questions
    end
  end

  def project_questions
    project_questions = Question.where(:id => questions.map { |q| Project.get_question_id(q)}) unless questions.blank?
    # project_questions = Question.current_questions if project_questions.blank?
    project_questions
  end

  def owner
    client
  end

  # Class Methods for questions as virtual attributes
  def self.question_key(q)
    "question_#{q.id}".to_sym
  end

  def self.get_question_id(q)
    q[0].to_s.split("_")[-1]
  end

  # add all Questions as virtual attributes for the Project model
  def self.virtualize_questions
    Question.all.each do |q|
      attr_accessible question_key(q), :as => [:owner, :admin]
      attr_accessor question_key(q)
    end
  end

  def self.unapproved_projects
    Project.where(:approved => nil)
  end

  def self.denied_projects
    Project.where(:approved => false)
  end

  def self.approved_projects
    Project.where(:approved => true)
  end

  def sector_color
    colors = ["red", "orange", "green", "blue", "purple"]
    sector_index = SECTORS.index(self.sector)
    partition = SECTORS.length / colors.length
    
    (0..colors.length).each do |i|
      if sector_index.between?(i * partition, (i + 1) * partition - 1)
        return colors[i]
      end
    end
  end

  Project.virtualize_questions
  
  # hack to modify serialized data (questions hash) using best_in_place in /app/views/shared/_project_questions.html.haml
  # based on http://stackoverflow.com/a/21286988
    
  def method_missing(method_name, *arguments, &block) # forewards the arguments to the correct methods
    if method_name.to_s =~ /questions_(.+)\=/
      key = method_name.to_s.match(/questions_(.+)=/)[1]
      self.send('data_setter=', key, arguments.first)
    elsif method_name.to_s =~ /questions_(.+)/
      key = method_name.to_s.match(/questions_(.+)/)[1]
      self.send('data_getter', key)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false) # prevents giving UndefinedMethod error
    method_name.to_s.start_with?('questions_') || super
  end

  def data_getter(key)
    self.questions[key.to_i] if self.questions.kind_of?(Array)
    self.questions[key.to_s] if self.questions.kind_of?(Hash)
  end

  def data_setter(key, value)
    self.questions[key.to_i] = value if self.questions.kind_of?(Array)
    self.questions[key.to_sym] = value if self.questions.kind_of?(Hash)
    value # the method returns value because best_in_place sets the returned value as text
  end
    
    
  def accessable_methods # returns a list of all the methods that are responded dynamicly
    self.questions.keys.map{|x| "questions_#{x.to_s}".to_sym }
  end

  private
    def mass_assignment_authorizer(user) # adds the list to the accessible list.
      super + self.accessable_methods
    end
end

