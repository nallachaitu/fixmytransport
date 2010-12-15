class CouncilContact < ActiveRecord::Base
  has_many :sent_emails, :as => :recipient
  has_many :outgoing_messages, :as => :recipient
  validates_presence_of :category
  has_paper_trail
  
  def name
    council_data = MySociety::MaPit.call('area', area_id)
    council_data['name']
  end
  
  def last_editor
    return nil if versions.empty? 
    return versions.last.whodunnit
  end
  
end
