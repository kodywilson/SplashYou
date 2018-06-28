#!/usr/bin/env ruby

require 'JSON'
require 'rest-client'

# File with base url and default headers
@params      = JSON.parse(File.read(File.join(File.dirname(__FILE__), "params.json")))

# Hash of videos and requested information
@vids = Hash.new

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

# Make api call for initial hash of videos
def grab_videos(vid_num = 10, page_num = 1) # Default is first page of 10 videos
  batch       = '?page[size]=' + vid_num.to_s
  page        = '&page[num]=' + page_num.to_s
  #sub_api_url    = @params['base_url'] + '?page[size]=' + "#{vid_num}" + '&page[num]=2' + '&fields=reach,title,youtube_url'
  sub_api_url    = @params['base_url'] + batch + page + '&fields=reach,title,youtube_url'
  headers        = @params['headers']

  getty = Planetoftheapis.new(headers: headers, meth: 'Get', params: {}, url: sub_api_url).api_call
  getty['response']['_embedded']['media-items'].each do |vid|
    # skip invalid urls and ignore playlists for now
    next unless vid['youtube_url'] =~ /\Ahttps:\/\/www.youtube.com\/watch\?v=/
    vid['youtube_url'] = vid['youtube_url'][0...43]
    tube_id = vid['youtube_url'][32...43]
    @vids[tube_id] = Hash.new
    @vids[tube_id]['reach']       = vid['reach']
    @vids[tube_id]['title']       = vid['title']
    @vids[tube_id]['youtube_url'] = vid['youtube_url']
  end
  return @vids
end

# Run this to grab a hash of videos and associated data
@vids = grab_videos(50, 1) # max request is 50 even though the doc says 1000
# Now we want to sort by reach in descending order
vid_array = @vids.sort_by {|k,v| v['reach']}.reverse
puts vid_array
