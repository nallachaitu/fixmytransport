# == Schema Information
# Schema version: 20100506162135
#
# Table name: location_searches
#
#  id                :integer         not null, primary key
#  transport_mode_id :integer
#  name              :string(255)
#  area              :string(255)
#  route_number      :string(255)
#  location_type     :string(255)
#  session_id        :string(255)
#  events            :text
#  active            :boolean
#  created_at        :datetime
#  updated_at        :datetime
#

class LocationSearch < ActiveRecord::Base
  
  serialize :events
  belongs_to :transport_mode
  
  def self.find_current(session_id)
    find(:first, :conditions => ['session_id = ? and active = ?', session_id, true], 
                 :order => 'created_at desc')
  end
  
  def self.close_session_searches(session_id)
    searches = find(:all, :conditions => ['session_id = ? and active = ?', session_id, true])
    searches.each { |search| search.toggle!(:active) }
  end
  
  def self.new_search!(session_id, params)
    close_session_searches(session_id)
    attributes = params[:problem][:location_attributes]
    attributes[:transport_mode_id] = params[:problem][:transport_mode_id]
    attributes[:location_type] = params[:problem][:location_type]
    attributes[:session_id] = session_id
    attributes[:active] = true
    attributes[:events] = []
    self.create!(attributes)
  end
  
  def description
    descriptors = [ transport_mode.name ]
    descriptors << location_type.tableize.singularize.humanize.downcase
    if !route_number.blank?
      descriptors << "'#{route_number}'"
    end
    if !name.blank?
      descriptors << "called '#{name}'"
    end
    if !area.blank?
      descriptors << "in #{area}"
    end
    descriptors.join(' ')
  end
  
  def add_choice(locations)
    location_list = locations.map{ |location| identifying_info(location) }
    self.events << { :type => :choice, 
                     :locations => location_list } 
    save
  end
  
  def add_location(location)
    self.events << { :type => :result, 
                     :location => identifying_info(location) }
    save
  end
  
  def add_response(location, response)
    response = 'invalid' unless ['success', 'fail'].include? response
    response = response.to_sym
    self.events << { :type => :response, 
                     :location => identifying_info(location),
                     :response => response }
    save
    close if response == :success
  end
  
  def add_method(method)
    self.events << { :type => :method, 
                     :method => method }
    save
  end
  
  def responded?(location)
    if self.events.detect{ |event| event[:type] == :response && event_about_location?(event, location) }
      return true
    else
      return false
    end
  end
  
  def event_about_location?(event, location)
    return true if event[:location] == identifying_info(location)
    return false 
  end
  
  def close
    LocationSearch.close_session_searches(session_id)
  end
  
  def identifying_info(location)
    { :id => location.id, :class => location.class.to_s }
  end
  
end
