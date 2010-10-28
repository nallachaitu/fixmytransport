# == Schema Information
# Schema version: 20100707152350
#
# Table name: routes
#
#  id                :integer         not null, primary key
#  transport_mode_id :integer
#  number            :string(255)
#  created_at        :datetime
#  updated_at        :datetime
#  type              :string(255)
#  name              :string(255)
#  region_id         :integer
#  cached_slug       :string(255)
#  operator_code     :string(255)
#  loaded            :boolean
#

require 'spec_helper'

describe Route do

  before(:each) do
    @valid_attributes = {
      :transport_mode_id => 1,
      :number => "value for number", 
      :region_id => 1
    }
  end

  it "should create a new instance given valid attributes" do
    route = Route.new(@valid_attributes)
    route.valid?.should be_true
  end
  
  it 'should require a transport mode' do 
    route = Route.new(@valid_attributes)
    route.transport_mode_id = nil
    route.valid?.should be_false
  end
  
  describe 'when loading' do 
    
    before do 
      @route = Route.new(@valid_attributes)
      @route.loaded = false
    end
  
    it 'should not require a region' do 
      @route.region_id = nil
      @route.valid?.should be_true
    end
  
  end
  
  describe 'when loaded' do 
  
    before do 
      @route = Route.new(@valid_attributes)
      @route.loaded = true
    end
    
    it 'should require a region' do 
      @route.region_id = nil
      @route.valid?.should be_false
    end
    
  end
  
  describe 'when giving its terminuses' do 
    
    it 'should return correct terminuses for an example route' do 
      routes(:victoria_to_haywards_heath).terminuses.should == [stop_areas(:victoria_station_root), stop_areas(:haywards_heath_station)]
    end
    
  end
  
  describe 'when giving its areas' do 
  
    describe 'when asked for only terminuses' do
      
      it 'should return a unique list of the names of the parent localities/localities of the terminuses' do 
        routes(:victoria_to_haywards_heath).areas(all=false).sort.should == ['Haywards Heath', 'London']
      end
      
      it 'should return a unique list of the names of the parent localities/localities of the route stops if the route has no terminuses' do 
        routes(:number_807_bus).areas(all=false).sort.should == ["Annfield Plain", "South Moor", "Stanley"]
      end
      
    end
    
    it 'should return a unique list of the names of the parent localities/localities of the stops' do 
      routes(:victoria_to_haywards_heath).areas.sort.should == ["Clapham Junction", "Croydon", "Gatwick Airport", "Haywards Heath", "London"]
    end
    
  end
  
  describe 'when finding existing routes' do 
  
    it 'should include routes with the same number and one stop in common with the new route' do 
      route = Route.new(:number => '807', 
                        :transport_mode => transport_modes(:bus))
      route.route_operators.build(:operator => operators(:a_bus_company))
      new_stop = mock_model(Stop, :atco_code => 'xxxx', :stop_areas => [])
      route.route_segments.build(:from_stop => stops(:arch_ne), :to_stop => new_stop, :from_terminus => true)
      Route.find_existing_routes(route).should include(routes(:number_807_bus))
    end
    
    it 'should include routes with the same number, no stops in common, but one stop area in common with the new route and the same operator' do
      route = Route.new(:number => '807', :transport_mode => transport_modes(:bus))
      route.route_operators.build(:operator => operators(:a_bus_company))
      new_stop = mock_model(Stop, :atco_code => 'xxxx', :stop_areas => [])
      route.route_segments.build(:from_stop => stops(:arch_sw), 
                                 :to_stop => new_stop,
                                 :from_terminus => true,
                                 :to_terminus => false)
      Route.find_existing_routes(route).should include(routes(:number_807_bus))
    end
    
    it 'should not include routes with the same number, no stops in common, but one stop area in common with the new route and a different operator' do
      route = Route.new(:number => '807', :transport_mode => transport_modes(:bus))
      route.route_operators.build(:operator => operators(:another_bus_company))
      new_stop = mock_model(Stop, :atco_code => 'xxxx', :stop_areas => [])
      route.route_segments.build(:from_stop => stops(:arch_sw), 
                                 :to_stop => new_stop,
                                 :from_terminus => true,
                                 :to_terminus => false)
      Route.find_existing_routes(route).should_not include(routes(:number_807_bus))
    end
  end
  
  describe 'when finding existing train routes' do 
    
    before do 
      @route = Route.new(:transport_mode => transport_modes(:train))
      @route.route_operators.build(:operator => operators(:a_train_company))
      @existing_route = routes(:victoria_to_haywards_heath)
      @terminus_segments = @existing_route.route_segments.select do |segment| 
        segment.from_terminus? || segment.to_terminus? 
      end
    end
    
    it 'should include a route with the same terminuses and the same operator' do 
      @terminus_segments.each do |route_segment|
        @route.route_segments.build(:from_stop => route_segment.from_stop,
                                    :to_stop => route_segment.to_stop, 
                                    :from_stop_area => route_segment.from_stop_area,
                                    :to_stop_area => route_segment.to_stop_area,
                                    :from_terminus => route_segment.from_terminus?,
                                    :to_terminus => route_segment.to_terminus?)
      end
      @route.route_segments.build(:from_stop => stops(:victoria_station_one), 
                                  :to_stop => stops(:victoria_station_two), 
                                  :from_stop_area => stop_areas(:victoria_station_root),
                                  :to_stop_area => stop_areas(:victoria_station_root),
                                  :from_terminus => false,
                                  :to_terminus => false)
      Route.find_existing_train_routes(@route).should include(@existing_route)
    end
    
    it 'should not include an identical route with a different operator' do 
      @route.route_operators.clear
      @route.route_operators.build(:operator => operators(:another_train_company))
      @terminus_segments.each do |route_segment|
        @route.route_segments.build(:from_stop => route_segment.from_stop,
                                    :to_stop => route_segment.to_stop, 
                                    :from_terminus => route_segment.from_terminus?,
                                    :to_terminus => route_segment.to_terminus?)
      end
      Route.find_existing_train_routes(@route).should_not include(@existing_route)
    end
    
    it "should include a route that passes through the new route's terminuses and has the same operator" do 
      non_terminus_segments = @existing_route.route_segments.select do |segment| 
        !segment.from_terminus? && !segment.to_terminus? 
      end
      # new route starts and ends in the middle of the existing route
      new_route_start = non_terminus_segments.first
      new_route_end = non_terminus_segments.second
      @route.route_segments.build(:from_stop => new_route_start.from_stop, 
                                  :to_stop => new_route_start.to_stop, 
                                  :from_stop_area => new_route_start.from_stop_area,
                                  :to_stop_area => new_route_start.to_stop_area,
                                  :from_terminus => true,
                                  :to_terminus => false)
      @route.route_segments.build(:from_stop => new_route_end.from_stop, 
                                  :to_stop => new_route_end.to_stop, 
                                  :from_stop_area => new_route_end.from_stop_area,
                                  :to_stop_area => new_route_end.to_stop_area, 
                                  :from_terminus => false,
                                  :to_terminus => true)                            
      Route.find_existing_train_routes(@route).should include(@existing_route)
    end
    
    it 'should include a route whose terminuses the new route stops at that has the same operator' do 
      # new route stops at the terminuses of the existing route but doesn't terminate there
      @terminus_segments.each do |route_segment|
        @route.route_segments.build(:from_stop => route_segment.from_stop,
                                    :to_stop => route_segment.to_stop, 
                                    :from_stop_area => route_segment.from_stop_area, 
                                    :to_stop_area => route_segment.to_stop_area,
                                    :from_terminus => false,
                                    :to_terminus => false)
      end
      # and has a couple of non-matching terminuses
      @route.route_segments.build(:from_stop => stops(:victoria_station_two),
                                  :to_stop => stops(:victoria_station_one), 
                                  :from_stop_area => stop_areas(:victoria_station_root),
                                  :to_stop_area => stop_areas(:victoria_station_root),
                                  :from_terminus => true,
                                  :to_terminus => false)
                                  
      @route.route_segments.build(:from_stop => stops(:haywards_heath_station_interchange), 
                                  :to_stop => stops(:gatwick_airport_station), 
                                  :from_stop_area => stop_areas(:haywards_heath_station),
                                  :to_stop_area => stop_areas(:gatwick_airport_station),
                                  :from_terminus => false, 
                                  :to_terminus => true)
      Route.find_existing_train_routes(@route).should include(@existing_route)
    end
  
  end
  
  
  describe 'when getting terminuses from a route name' do 
  
    it 'should get "London Victoria" and "Haywards Heath" from "London Victoria to Haywards Heath"' do 
      Route.get_terminuses("London Victoria to Haywards Heath").should == ['London Victoria', 'Haywards Heath']
    end
    
  end
  
  describe 'when adding a route' do 
  
    it 'should raise an exception if a route to be merged has campaigns associated with it' do
      Route.stub!(:find_existing).and_return([routes(:victoria_to_haywards_heath)])
      route = Route.new(:campaigns => [mock_model(Campaign)], :transport_mode_id => 5, :number => '43')
      lambda{ Route.add!(route) }.should raise_error(/Can't merge route with campaigns/)
    end
    
    it 'should save the route if no existing routes are found' do 
      Route.stub!(:find_existing).and_return([])
      route = Route.new(:transport_mode_id => 5, :number => '43')
      route.should_receive(:save!)
      Route.add!(route)
    end
    
    it 'should transfer route operator associations when merging overlapping routes' do 
      existing_route = routes(:victoria_to_haywards_heath)
      existing_route.route_operators.size.should == 1
      Route.stub!(:find_existing).and_return([existing_route])
      route_operator = RouteOperator.new(:operator => Operator.new)
      route = Route.new(:transport_mode_id => 5, 
                        :number => '43', 
                        :route_operators => [route_operator])
      Route.add!(route)
      existing_route.route_operators.size.should == 2
    end 
    
    it 'should not add duplicate route operator associations when merging overlapping routes' do 
      existing_route = routes(:victoria_to_haywards_heath)
      existing_operator = existing_route.operators.first
      existing_route.route_operators.size.should == 1
      Route.stub!(:find_existing).and_return([existing_route])
      route = Route.new(:transport_mode_id => 5, 
                        :number => '43', 
                        :route_operators => [RouteOperator.new(:operator => existing_operator)])
      Route.add!(route)
      existing_route.route_operators.size.should == 1
    end
    
    it 'should transfer route segment when merging overlapping routes' do 
      existing_route = routes(:victoria_to_haywards_heath)
      existing_route.route_segments.size.should == 4
      Route.stub!(:find_existing).and_return([existing_route])
      route_segment = RouteSegment.create(:from_stop => stops(:borough_station),
                                          :to_stop => stops(:staple_street))
      route = Route.new(:transport_mode_id => 5, 
                        :number => '43', 
                        :route_segments => [route_segment])
      Route.add!(route)
      existing_route.route_segments.size.should == 5
    end
    
    it 'should not add duplicate route segments when merging overlapping routes' do 
      existing_route = routes(:victoria_to_haywards_heath)
      Route.stub!(:find_existing).and_return([existing_route])
      existing_route.route_segments.size.should == 4 
      route_segment = existing_route.route_segments.first
      route = Route.new(:transport_mode_id => 5, 
                        :number => '43')
      route.route_segments.build(:from_stop => route_segment.from_stop, 
                                 :to_stop => route_segment.to_stop, 
                                 :from_terminus => route_segment.from_terminus, 
                                 :to_terminus => route_segment.to_terminus)                  
      Route.add!(route)
      existing_route.route_segments.size.should == 4
    end
    
    it 'should not leave as terminuses stops that are terminuses in an existing route but not terminuses in a duplicate' do 
      existing_route = routes(:victoria_to_haywards_heath)
      Route.stub!(:find_existing).and_return([existing_route])
      existing_route_segment = existing_route.route_segments.detect{ |segment| segment.from_terminus? }
      existing_route_segment.from_terminus?.should be_true
      route_segment = mock_model(RouteSegment, :from_stop => existing_route_segment.from_stop, 
                                               :to_stop => existing_route_segment.to_stop,
                                               :from_terminus? => false, 
                                               :to_terminus? => false, 
                                               :destroy => true)
      route = Route.new(:transport_mode_id => 5, 
                        :number => '43', 
                        :route_segments => [route_segment])
      Route.add!(route)
      RouteSegment.find(existing_route_segment.id).from_terminus.should be_false
    end
    
  end

  describe "when counting routes without operators " do 
    
    it 'should return routes without route operators' do 
      Route.count_without_operators.should == 3
    end
    
  end
  
  describe 'when finding codes without operators' do 
    
    it 'should return codes (with counts) that are attached to routes but have no operators' do 
      Route.find_codes_without_operators.should == [['TUBE', '2'], ['LONDON_BUS', '1']]
    end
    
  end
  
  describe 'when counting codes without operators' do 
  
    it 'should return the number of operator codes in use for which there are no operators' do 
      Route.count_codes_without_operators.should == 2
    end
    
  end
  
  describe 'when asked for responsible organizations' do 
    
    it 'should return the operators' do 
      mock_operator = mock_model(Operator)
      route = Route.new
      route.stub!(:operators).and_return([mock_operator])
      route.responsible_organizations.should == [mock_operator]
    end
     
  end
  
  describe 'as a transport location' do 
    
    before do 
      @instance = Route.new
    end
    
    it_should_behave_like 'a transport location' 
  
  end
end
