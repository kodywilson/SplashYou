require './SplashYou.rb'

describe "get_parameters" do
  it 'reads parameters from json file' do
    @params      = JSON.parse(File.read(File.join(File.dirname(__FILE__), "../params.json")))
    content_type = @params['headers']['Content-Type']
    expect(content_type).to eq 'application/x-www-form-urlencoded'
  end
end
