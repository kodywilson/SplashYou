#!/usr/bin/env ruby

require 'fileutils'
gem 'google-api-client', '>0.7'
require 'google/apis'
require 'google/apis/youtube_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'JSON'
require 'rest-client'
require 'rubygems'

# File with base url and default headers
@params = JSON.parse(File.read(File.join(File.dirname(__FILE__), "params.json")))

# Hash of videos and requested information
@vids = Hash.new

# Initialize page counter and page size
@page_counter = 1
@page_size    = 5

# REPLACE WITH URI FOR YOUR CLIENT
OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'YouTube Data API Ruby Tests'

# REPLACE WITH NAME/LOCATION OF YOUR client_secrets.json FILE
CLIENT_SECRETS_PATH = 'client_secret.json'

# REPLACE FINAL ARGUMENT WITH FILE WHERE CREDENTIALS WILL BE STORED
CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                             "youtube-quickstart-ruby-credentials.yaml")

# SCOPE FOR WHICH THIS SCRIPT REQUESTS AUTHORIZATION
SCOPE = Google::Apis::YoutubeV3::AUTH_YOUTUBE_READONLY

# Authenticate so we can use Google YouTube api
def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(
    client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts "Open the following URL in the browser and enter the " +
         "resulting code after authorization"
    puts url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI)
  end
  credentials
end

# Initialize the API
service = Google::Apis::YoutubeV3::YouTubeService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

# api call class with sane defaults
class Planetoftheapis

  VERBS = {
    'delete' => :Delete,
    'get'    => :Get,
    'post'   => :Post,
    'put'    => :Put
  }

  def initialize(headers: {}, meth: 'Get', params: {}, url: 'https://testing.testing123.net/')
    @headers = headers
    @meth    = meth
    @params  = params
    @url     = url
  end

  def api_call
    if @url.to_s =~ /splash/ || @url.to_s =~ /google/ || @url.to_s =~ /api/
      responder(make_call)
    else
      error_text("api_call", @url.to_s, "subsplash or youtube api url")
    end
  end

  def make_call
    @params = @params.to_json unless @meth.downcase == 'get' || @meth.downcase == 'delete'
    begin
      response = RestClient::Request.execute(headers: @headers,
                                             method: VERBS[@meth.downcase],
                                             payload: @params,
                                             timeout: 30,
                                             url: @url,
                                             verify_ssl: false)
    rescue => e
      e.response
    else
      response
    end
  end

  def error_text(method_name, url, wanted)
    response = {
      "response" =>
        "ERROR: Wrong url for the #{method_name} method.\n"\
        "Sent: #{url}\n"\
        "Expected: \"#{wanted}\" as part of the url.",
      "status" => 400
    }
  end

  def responder(response)
    response = {
      "response" => JSON.parse(response.body),
      "status" => response.code.to_i
    }
  end

end

# Check response for errors
def check_api_response(got)
  error = false
  if got['response'].has_key? 'message'
    error = true if got['response']['message'] =~ /Endpoint request timed out/
  end
  if got['response'].has_key? '_embedded'
    if got['response']['_embedded'].has_key? 'media-items'
      error = true if got['response']['_embedded']['media-items'] == nil
    end
  end
  if error == true
    @vids['error']    = true
    @vids['response'] = got['response']
    @vids['status']   = got['status']
  end
end

# Getting channel information by username - using to test authentication
def channels_list_by_username(service, part, **params)
  response = service.list_channels(part, params).to_json
  item = JSON.parse(response).fetch("items")[0]

  puts ("This channel's ID is #{item.fetch("id")}. " +
        "Its title is '#{item.fetch("snippet").fetch("title")}', and it has " +
        "#{item.fetch("statistics").fetch("viewCount")} views.")
end

# Make call to YouTube api and check duration of vidoes
def check_video(vid)
  vid['youtube_url'] = vid['youtube_url'][0...43]
  tube_id = vid['youtube_url'][32...43]
  @vids[tube_id] = Hash.new
  @vids[tube_id]['reach']       = vid['reach']
  @vids[tube_id]['title']       = vid['title']
  @vids[tube_id]['youtube_url'] = vid['youtube_url']
end

# Make api calls for requested number of videos
def grab_videos(vid_num = 10) # Default is 10 videos total
  batch         = '?page[size]=' + @page_size.to_s
  headers       = @params['headers']
  while @vids.length < vid_num
    page        = '&page[num]=' + @page_counter.to_s
    sub_api_url = @params['base_url'] + batch + page + '&fields=reach,title,youtube_url'

    getty = Planetoftheapis.new(headers: headers, meth: 'Get', params: {}, url: sub_api_url).api_call
    check_api_response(getty)
    something_went_wrong if @vids['error'] == true
    getty['response']['_embedded']['media-items'].each do |vid|
      # skip invalid urls and ignore playlists for now
      next unless vid['youtube_url'] =~ /\Ahttps:\/\/www.youtube.com\/watch\?v=/
      check_video(vid)
    end
    @page_counter = @page_counter + 1
  end
  return @vids
end

def something_went_wrong
  puts "Something went wrong and the api call failed!"
  puts @vids
  exit 1
end

# Run this to grab a hash of videos and associated data
# The api seems less reliable the more you ask of it so I am going to move the
# page size to the grab_videos method and instead here ask for number of videos
# for the html table. We will keep making calls until I have enough videos
@vids = grab_videos(10) # final number of videos to present in table
something_went_wrong if @vids['error'] == true
channels_list_by_username(service, 'snippet,contentDetails,statistics', for_username: 'GoogleDevelopers')
# Now we want to sort by reach in descending order
vid_array = @vids.sort_by {|k,v| v['reach']}.reverse
puts vid_array
