require 'spec_helper'

describe Parsers::NaptanParser do 

  def example_file filename
    File.join(RAILS_ROOT, 'spec', 'examples', 'NaPTAN', filename)
  end
  
  describe 'when parsing an example CSV file of stop area data' do 
    
    before(:all) do 
      @parser = Parsers::NaptanParser.new
      @stop_areas = []
      @parser.parse_stop_areas(example_file("StopAreas.csv")){ |stop_area| @stop_areas << stop_area }
    end
    
    it 'should extract the stop area codes' do 
      @stop_areas.first.code.should == '020G33094'
      @stop_areas.second.code.should == '020G33100'      
    end
    
    it 'should extract the names' do 
      @stop_areas.first.name.should == 'Willoughby Close'
      @stop_areas.second.name.should == 'Green End Road'
    end
    
    it 'should extract the statuses' do 
      @stop_areas.first.status.should == 'act'
      @stop_areas.second.status.should == 'del'
    end
    
  end
  
  describe 'when parsing an example CSV file of stop data' do 
  
    before(:all) do 
      @parser = Parsers::NaptanParser.new
      @stops = []
      @parser.parse_stops(example_file("Stops.csv")){ |stop| @stops << stop }
    end
    
    it 'should extract the atco codes' do 
      @stops.first.atco_code.should == '01000053203'
      @stops.second.atco_code.should == '01000053204'
    end
    
    it 'should extract the statuses' do 
      @stops.first.status.should == 'act'
      @stops.second.status.should == 'act'
    end
    
    it 'should extract and clean the street' do 
      @stops.first.street.should be_nil
    end
    
  end
  
  describe 'when parsing an example CSV file of stop area types' do 
    
    before(:all) do 
      TransportMode.stub!(:find_by_naptan_name).and_return(mock_model(TransportMode))
      @stop_area_types = []
      @parser = Parsers::NaptanParser.new
      @parser.parse_stop_area_types(example_file("StopAreaTypes.csv")){ |stop_area_type| @stop_area_types << stop_area_type }
    end
    
    it 'should extract the NaPTAN stop area type code' do 
      @stop_area_types.first.code.should == 'GTMU'
    end
    
  end
  
  describe 'when parsing an example CSV file of stop types' do 
  
    before(:all) do 
      TransportMode.stub!(:find_by_naptan_name).and_return(mock_model(TransportMode))
      @stop_types = []
      @parser = Parsers::NaptanParser.new
      @parser.parse_stop_types(example_file("StopTypes.csv")){ |stop_type| @stop_types << stop_type }
    end
    
    it 'should extract the NaPTAN stop type code' do 
      @stop_types.first.code.should == 'BCT'
      @stop_types.second.code.should == 'FER'
    end
    
    it 'should extract the sub-type code' do 
      @stop_types.first.sub_type.should == 'MKD'
      @stop_types.second.sub_type.should be_nil
    end
    
    it 'should set the "on_street" attribute correctly' do 
      @stop_types.first.on_street.should be_true
      @stop_types.second.on_street.should be_false
    end
    
  end
  
  describe 'when parsing an example CSV file of stops in stop areas' do 
    
    before(:each) do 
      @parser = Parsers::NaptanParser.new
      @stop = mock_model(Stop)
      @stop_area = mock_model(StopArea)
      Stop.stub!(:find).and_return(@stop)
      StopArea.stub!(:find).and_return(@stop_area)
    end
  
    it 'should look for any stops with each atco code found in a case-insensitive comparison' do 
      Stop.should_receive(:find).with(:first, :conditions => ["lower(atco_code) = ?", '020033094'], :include => nil).and_return(@stop)
      Stop.should_receive(:find).with(:first, :conditions => ["lower(atco_code) = ?", '020033095'], :include => nil).and_return(@stop)
      @parser.parse_stop_area_memberships(example_file("StopsInArea.csv")){|membership|}
    end
    
    it 'should look for any stop areas with each area code found in a case-insensitive comparison' do 
      StopArea.should_receive(:find).with(:first, :conditions => ["lower(code) = ?", '020g33094']).exactly(2).times.and_return(@stop_area)
      @parser.parse_stop_area_memberships(example_file("StopsInArea.csv")){|membership|}
    end
    
    it 'should extract the modification datetime' do 
      memberships = []
      @parser.parse_stop_area_memberships(example_file("StopsInArea.csv")){|membership| memberships << membership }
      memberships.first.modification_datetime.should == Date.new(2009, 4, 13)
      memberships.second.modification_datetime.should == Date.new(2009, 5, 13)
    end
  
  end

end
