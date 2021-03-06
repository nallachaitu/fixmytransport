# == Schema Information
# Schema version: 20100707152350
#
# Table name: users
#
#  id                :integer         not null, primary key
#  name              :string(255)
#  email             :string(255)
#  created_at        :datetime
#  updated_at        :datetime
#  wants_fmt_updates :boolean
#

require 'spec_helper'

describe User do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
    }
  end

  describe 'when saving a registered user' do

    before do
      @user = User.new
      @user.email = 'test@example.com'
      @user.password = 'password'
      @user.password_confirmation = 'password'
      @user.name = 'A Test Name'
      @user.registered = true
    end

    after do
      user = User.find_by_email("test@example.com")
      user.destroy if user
    end

    it 'should not be valid if there is no user name' do
      @user.name = nil
      @user.valid?.should be_false
    end

    it 'should be valid if there is a name' do
      @user.valid?.should be_true
    end

    it 'should be invalid without a password if registered and without access tokens' do
      @user.registered = true
      @user.password = nil
      @user.password_confirmation = nil
      @user.valid?.should be_false
    end

    it 'should be valid without a password if unregistered' do
      @user.registered = false
      @user.password = nil
      @user.password_confirmation = nil
      @user.valid?.should be_true
    end

    it 'should be valid without a password if there are access tokens (i.e. login via Facebook)' do
      @user.registered = true
      @user.stub!(:access_tokens).and_return([mock_model(AccessToken)])
      @user.password = nil
      @user.password_confirmation = nil
      @user.valid?.should be_true
    end

    it 'should be invalid without a password if there are access tokens, but the force_new_record_validation flag is set' do
      @user.registered = true
      @user.stub!(:access_tokens).and_return([mock_model(AccessToken)])
      @user.password = nil
      @user.password_confirmation = nil
      @user.force_new_record_validation = true
      @user.valid?.should be_false
    end

    describe 'if this is a new record' do

      before do
        @user.stub!(:new_record?).and_return(true)
      end

      it 'should add an error if the name is some variant of "anon"' do
        ['anon', 'anonymous', 'anonymos', 'anonymously'].each do |anon_variant|
          @user.name = anon_variant
          @user.valid?.should be_false
          @user.errors.on(:name).should == "Please enter your full name. See our <a href='/about#names' target='_blank'>policy on names</a>."
        end
      end

      it 'should add an error if the name is less than 5 characters' do
        @user.name = 'A B'
        @user.valid?.should be_false
        @user.errors.on(:name).should == "Please enter your full name. See our <a href='/about#names' target='_blank'>policy on names</a>."
      end

      it 'should add an error if the name does not have a non space, followed by a space, followed by a non space' do
        ['Firstname ', ' Lastname'].each do |no_space|
          @user.name = no_space
          @user.valid?.should be_false
          @user.errors.on(:name).should == "Please enter your full name. See our <a href='/about#names' target='_blank'>policy on names</a>."
        end
      end

      describe 'if a password is not required' do

        before do
          @admin_user = AdminUser.new
          @user.admin_user = @admin_user
          @user.stub!(:password_not_required).and_return(true)
        end

        it 'should not try to reset an admin password' do
          @admin_user.should_not_receive(:reset_password!)
          @user.save
        end

      end

      describe 'if there is an associated admin user' do

        before do
          @admin_user = AdminUser.new
          @admin_user.stub!(:reset_password!)
          @user.admin_user = @admin_user
        end

        describe 'if the user tries to set their password to a different one from the admin password' do

          before do
            @admin_user.stub!(:valid_password?).with('password').and_return(false)
          end

          it 'should reset the admin password' do
            @admin_user.should_not_receive(:reset_password!)
            @user.save
          end

        end

        describe 'if the user tries to set their password to the admin password' do

          before do
            @admin_user.stub!(:valid_password?).with('password').and_return(true)
          end

          it 'should reset the admin password' do
            @admin_user.should_receive(:reset_password!)
            @user.save
          end

        end

      end

    end

    describe 'if this is not a new record but force_new_record_validation has been set' do

      before do
        @user.stub!(:new_record?).and_return(false)
        @user.force_new_record_validation = true
      end

      it 'should add an error in the name is less than 5 characters' do
        @user.name = 'A B'
        @user.valid?.should be_false
        @user.errors.on(:name).should == "Please enter your full name. See our <a href='/about#names' target='_blank'>policy on names</a>."
      end

    end

    describe 'if this is not a new record and force_new_record_validation has not been set' do

      before do
        @user.stub!(:new_record?).and_return(false)
      end

      it 'should not add an error if the name is less than 5 characters' do
        @user.name = 'A B'
        @user.valid?.should be_true
      end

    end

  end

  describe 'when marking an issue as seen' do 
    
    describe 'when the issue is a campaign' do 
      
      describe 'when the user is a campaign supporter' do 
        
        before do
          @user = User.new
          @other_user = User.new
          @mock_campaign = mock_model(Campaign, :initiator => @other_user)
          @mock_supporter = mock_model(CampaignSupporter, :campaign => @mock_campaign,
                                                          :supporter => @user)
          @user.stub!(:campaign_supporters).and_return(mock('supporters', :confirmed => [@mock_supporter]))

        end
        
        describe 'if the supporter is a new supporter' do 
          
          before do
            @mock_supporter.stub!(:new_supporter?).and_return(true)
          end
          
          it 'should mark the supporter as not a new supporter' do 
            @mock_supporter.should_receive(:new_supporter=).with(false)
            @mock_supporter.should_receive(:save)
            @user.mark_seen(@mock_campaign)
          end
        end
        
      end
      
      describe 'when the user is the campaign initiator' do 
        
        before do
          @user = User.new
          @mock_campaign = mock_model(Campaign, :initiator => @user)
        end
        
        describe 'if the campaign has not been seen by the initiator' do 
        
          before do
            @mock_campaign.stub!(:initiator_seen?).and_return(false)
          end
          
          it 'should mark the campaign as seen by the initiator' do 
            @mock_campaign.should_receive(:update_attribute).with("initiator_seen", true)
            @user.mark_seen(@mock_campaign)
          end
      
        end
        
        describe 'if the campaign has been seen by the initiator' do 
          
          before do
            @mock_campaign.stub!(:initiator_seen?).and_return(true)
          end
          
          it 'should not mark the campaign as seen by the initiator' do 
            @mock_campaign.should_not_receive(:update_attribute).with("initiator_seen", true)
            @user.mark_seen(@mock_campaign)
          end
          
        end
        
        
      end
      
    end
    
    
    describe 'when the user is the problem reporter' do 
      
      describe 'when the reporter has not seen the problem' do 
      
        before do 
          @user = User.new
          @mock_problem = mock_model(Problem, :reporter_seen? => false,
                                              :reporter => @user)
        end
        
        it 'should mark the reporter as having seen the problem' do 
          @mock_problem.should_receive(:update_attribute).with('reporter_seen', true)
          @user.mark_seen(@mock_problem)
        end
        
      end
      
    end
    
  end
  
  describe 'when asked if can admin users' do

    before do
      @user = User.new
      @user.stub!(:is_admin?).and_return(true)
    end

    it 'should return false is is_admin? returns false' do
      @user.stub!(:is_admin?).and_return(false)
      @user.can_admin?(:users).should == false
    end

    describe 'if is_admin? returns true' do

      before do
        @user.stub!(:is_admin?).and_return(true)
      end

      it 'should return true if can_admin_users? returns true' do
        @user.stub!(:can_admin_users?).and_return(true)
        @user.can_admin?(:users).should == true
      end

      it 'should return false if can_admin_users? returns false' do
        @user.stub!(:can_admin_users?).and_return(false)
        @user.can_admin?(:users).should == false
      end
    end

  end

  describe 'when handling an external auth token' do

    describe 'when getting facebook data' do

      before do
        @mock_io = mock('IO stream', :read => "")
        JSON.stub!(:parse)
        User.stub!(:open).and_return(@mock_io)
      end

      it 'should make a call to the facebook graph URL, passing the access token and asking for name, email and profile photo' do
        MySociety::Config.stub!(:get).with('FACEBOOK_GRAPH_API_URL', '').and_return('http://example.com')
        User.should_receive(:open).with("http://example.com/me?access_token=mytoken&fields=name,email,picture&type=large").and_return(@mock_io)
        User.get_facebook_data('mytoken')
      end

      it 'should parse the response as JSON' do
        JSON.should_receive(:parse)
        User.get_facebook_data('mytoken')
      end

    end

    describe 'when the source is facebook' do

      before do
        @mock_user = mock_model(User, :save_without_session_maintenance => true,
                                      :access_tokens => [],
                                      :registered= => true,
                                      :suspended? => false,
                                      :profile_photo_url= => nil,
                                      :profile_photo? => false,
                                      :error_on_bad_profile_photo_url= => nil,
                                      :errors => mock('errors', :full_messages => []))
        @mock_user.access_tokens.stub!(:build).and_return(true)
        User.stub!(:new).and_return(@mock_user)
        User.stub!(:get_facebook_data).and_return({'id' => 'myfbid',
                                                   'name' => 'Test Name',
                                                   'email' => 'test@example.com',
                                                   'picture' => 'http://profile.example.com/mypicture.jpg'})
        @mock_session = mock_model(UserSession, :httponly= => nil,
                                                :save => nil)
        UserSession.stub!(:new).and_return(@mock_session)
      end

      it 'should set the user as registered' do
        @mock_user.should_receive(:registered=).with(true)
        User.handle_external_auth_token('mytoken', 'facebook', false)
      end

      it 'should look up user records by the facebook ID' do
        AccessToken.should_receive(:find).with(:first, :conditions => ['key = ? and token_type = ?', 'myfbid', 'facebook'])
        User.handle_external_auth_token('mytoken', 'facebook', false)
      end

      describe 'if the user is suspended' do

        before do
          @mock_user.stub!(:suspended?).and_return(true)
        end

        it 'should throw an exception' do
          lambda{ User.handle_external_auth_token('mytoken', 'facebook', false) }.should raise_exception()
        end

      end

      describe 'if the user is not suspended' do

        before do
          @mock_user.stub!(:suspended?).and_return(false)
        end

        it 'should create a session' do
          UserSession.should_receive(:new).and_return(@mock_session)
          User.handle_external_auth_token('mytoken', 'facebook', false)
        end

        it 'should make the session http only (cookie setting)' do
          @mock_session.should_receive(:httponly=).with(true)
          User.handle_external_auth_token('mytoken', 'facebook', false)
        end

        it 'should save the session' do
          @mock_session.should_receive(:save)
          User.handle_external_auth_token('mytoken', 'facebook', false)
        end

      end

      describe 'when an access token does not exist' do

        before do
          AccessToken.stub!(:find).and_return(nil)
        end

        describe "when the facebook data does not contain enough information and the user can't be saved" do

          before do
            User.stub!(:get_facebook_data).and_return({'id' => 'myfbid',
                                                       'name' => 'Test Name',
                                                       'email' => nil,
                                                       'picture' => 'http://profile.example.com/mypicture.jpg'})
            @mock_user.stub!(:save_without_session_maintenance).and_return(false)
          end

          it 'should raise an exception' do
            lambda{ User.handle_external_auth_token('mytoken', 'facebook', false) }.should raise_exception()
          end

        end


        it 'should search for the user by email ignoring case' do
          User.stub!(:get_facebook_data).and_return({'id' => 'myfbid',
                                                     'name' => 'Test Name',
                                                     'email' => 'Test@Example.com',
                                                     'picture' => 'http://profile.example.com/mypicture.jpg'})
          User.should_receive(:find).with(:first, :conditions => ['lower(email) = ?', 'test@example.com'])
          User.handle_external_auth_token('mytoken', 'facebook', false)
        end

        it 'should set the remote profile photo url' do
          @mock_user.should_receive(:profile_photo_url=).with("http://profile.example.com/mypicture.jpg")
          User.handle_external_auth_token('mytoken', 'facebook', false)
        end

        it 'should set the user model to not error if there is an issue with the remote url' do
          @mock_user.should_receive(:error_on_bad_profile_photo_url=).with(false)
          User.handle_external_auth_token('mytoken', 'facebook', false)
        end

        it 'should not set the remote profile photo url if the remote url is a static one' do
          User.stub!(:get_facebook_data).and_return({'id' => 'myfbid',
                                                     'name' => 'Test Name',
                                                     'email' => 'test@example.com',
                                                     'picture' => 'http://static.example.com/mypicture.jpg'})
          @mock_user.should_not_receive(:profile_photo_url=)
          User.handle_external_auth_token('mytoken', 'facebook', false)
        end

        it 'should not replace an existing uploaded profile photo with a facebook photo' do
          @mock_user.stub!(:profile_photo_remote_url).and_return(nil)
          @mock_user.stub!(:profile_photo?).and_return(true)
          User.handle_external_auth_token('mytoken', 'facebook', false)
        end

      end

    end

  end

  describe 'when updating remote profile photos' do

    before do
      User.stub!(:get_facebook_app_access_token).and_return('app_token')
      User.stub!(:get_facebook_batch_api_data)
      @mock_http = mock('http session', :use_ssl= => nil,
                                        :verify_mode= => nil,
                                        :ca_path= => nil)
      Net::HTTP.stub!(:new).and_return(@mock_http)
    end


    describe 'when a user has a facebook access token and no profile photo' do

      before do
        @user_without_profile_photo = mock_model(User, :profile_photo? => false,
                                                       :profile_photo_url= => nil,
                                                       :profile_photo_remote_url => nil,
                                                       :save_without_session_maintenance => true,
                                                       :error_on_bad_profile_photo_url= => nil)
        @token_for_user_without_profile_photo = mock_model(AccessToken, :user => @user_without_profile_photo,
                                                                        :key => 'mykey')
        AccessToken.stub!(:find_each).and_yield(@token_for_user_without_profile_photo)
        AccessToken.stub!(:find).and_return(@token_for_user_without_profile_photo)
        picture_data = {'id' => 'mykey', 'picture' => 'http://example.com/image.jpg'}
        User.stub!(:get_facebook_batch_api_data).and_return([{'body' => picture_data.to_json}])
      end

      it 'should get an app facebook access token' do
        User.should_receive(:get_facebook_app_access_token)
        User.update_remote_profile_photos
      end

      it "should ask facebook for the user's profile picture" do
        expected_batch_request = [{:method=>"GET", :relative_url=>"mykey?fields=id,picture&type=large"}]
        User.should_receive(:get_facebook_batch_api_data).with(@mock_http,
                                                               expected_batch_request,
                                                               'app_token',
                                                               false)
        User.update_remote_profile_photos
      end

      describe 'if the new url is static' do

        before do
          picture_data = {'id' => 'mykey', 'picture' => 'http://static.example.com/image.jpg'}
          User.stub!(:get_facebook_batch_api_data).and_return([{'body' => picture_data.to_json}])
        end

        it 'should not set the remote profile url' do
          @user_without_profile_photo.should_not_receive(:profile_photo_url=)
          User.update_remote_profile_photos
        end

      end

      describe 'if the picture url from facebook is not static' do

        before do
          picture_data = {'id' => 'mykey', 'picture' => 'http://example.com/image.jpg'}
          User.stub!(:get_facebook_batch_api_data).and_return([{'body' => picture_data.to_json}])
        end

        it 'should set the user to error on a bad remote profile photo url' do
          @user_without_profile_photo.should_receive(:error_on_bad_profile_photo_url=).with(true)
          User.update_remote_profile_photos
        end

        it 'should set the remote profile url' do
          @user_without_profile_photo.should_receive(:profile_photo_url=).with('http://example.com/image.jpg')
          User.update_remote_profile_photos
        end

        it 'should save the user' do
          @user_without_profile_photo.should_receive(:save_without_session_maintenance)
          User.update_remote_profile_photos
        end

      end

    end

    describe 'when a user has a profile photo' do

      before do
        @user_with_profile_photo = mock_model(User, :profile_photo? => true,
                                                    :save_without_session_maintenance => true,
                                                    :error_on_bad_profile_photo_url= => nil,
                                                    :profile_photo_url= => nil)
        @token_for_user_with_profile_photo = mock_model(AccessToken, :user => @user_with_profile_photo,
                                                                     :key => 'mykey')
        AccessToken.stub!(:find_each).and_yield(@token_for_user_with_profile_photo)
        AccessToken.stub!(:find).and_return(@token_for_user_with_profile_photo)
        picture_data = {'id' => 'mykey', 'picture' => 'http://example.com/image.jpg'}
        User.stub!(:get_facebook_batch_api_data).and_return([{'body' => picture_data.to_json}])
      end

      describe 'when the profile photo is not remote' do

        before do
          @user_with_profile_photo.stub!(:profile_photo_remote_url).and_return(nil)
        end

        it 'should not set the profile photo url' do
          @user_with_profile_photo.should_not_receive(:profile_photo_url=)
          User.update_remote_profile_photos
        end

      end

      describe 'if the profile photo is remote' do

        before do
          @user_with_profile_photo.stub!(:profile_photo_remote_url).and_return('http://example.com/image.jpg')
        end

        describe 'if the url from facebook is different from the existing url and not static' do

          before do
            picture_data = {'id' => 'mykey', 'picture' => 'http://different.example.com/image.jpg'}
            User.stub!(:get_facebook_batch_api_data).and_return([{'body' => picture_data.to_json}])
          end

          it 'should set the user to error on a bad remote profile photo url' do
            @user_with_profile_photo.should_receive(:error_on_bad_profile_photo_url=).with(true)
            User.update_remote_profile_photos()
          end

          it 'should set the remote profile url' do
            expected_url = 'http://different.example.com/image.jpg'
            @user_with_profile_photo.should_receive(:profile_photo_url=).with(expected_url)
            User.update_remote_profile_photos()
          end

          it 'should save the user' do
            @user_with_profile_photo.should_receive(:save_without_session_maintenance)
            User.update_remote_profile_photos()
          end

        end

        describe 'if the new url is static' do

          before do
            picture_data = {'id' => 'mykey', 'picture' => 'http://static.example.com/image.jpg'}
            User.stub!(:get_facebook_batch_api_data).and_return([{'body' => picture_data.to_json}])
          end

          it 'should not set the remote profile url' do
            @user_with_profile_photo.should_not_receive(:profile_photo_url=)
            User.update_remote_profile_photos()
          end

        end

        describe "if the existing url is the same as the user's remote profile url" do

          before do
            picture_data = {'id' => 'mykey', 'picture' => 'http://example.com/image.jpg'}
            User.stub!(:get_facebook_batch_api_data).and_return([{'body' => picture_data.to_json}])
          end

          it 'should not set the remote profile url' do
            @user_with_profile_photo.should_not_receive(:profile_photo_url=)
            User.update_remote_profile_photos()
          end

        end
      end

    end
  end

end
