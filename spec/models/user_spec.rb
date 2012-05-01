require 'spec_helper'

describe User do
  before do
    @user = User.create(:email => "testuser@example.com", 
                        :password => "password", 
                        :password_confirmation => "password")
  end
  after do
    @user.delete
  end
  it "should have a login and email" do
    @user.login.should == "testuser@example.com"
    @user.email.should == "testuser@example.com"
  end
  
end
