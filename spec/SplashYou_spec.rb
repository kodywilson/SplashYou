require './SplashYou.rb'

describe 'Build html table from api data' do
  before(:all) do
    @params = JSON.parse(File.read(File.join(File.dirname(__FILE__), "../params.json")))
    @vids   = Hash.new
  end

  describe "get_parameters" do
    it 'reads parameters from json file' do
      content_type = @params['headers']['Content-Type']
      expect(content_type).to eq 'application/x-www-form-urlencoded'
    end
  end

  describe "grab_videos" do
    it 'hits api and fills hash' do
      @vids = grab_videos(10)
      title = @vids['DH_AFpnt_tU']['title']
      expect(title).to eq 'Agave Theophilus Testimony'
    end
  end
end
