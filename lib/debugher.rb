require "debugher/version"

module Debugher
  require 'robots'
	require 'nokogiri'
	require 'addressable/uri'
	require 'cgi'

	class Debugger
	  FILE_TYPES = ['.mp3', '.m4a', '.MP3']
	  attr_accessor :url

	  # pass a url as a string to initialize
	  def initialize(url)
	    $stdout.sync = true
	    @uri = URI.parse(url)
	    @url = @uri.class == URI::HTTP ? url : "http://#{url}"
	    @uri = URI.parse(@url)
	    @opened_url = open_url
	  end

	  def open_url
	    url_object = nil
	    ua = Debugger.user_agent
	    @robot = Robots.new(ua)
	    if @robot.allowed?(@uri)
	      begin
	        url_object = open(@uri,
	                     "User-Agent" => ua,
	                     "From" => "hello@rakkit.com",
	                     "Referer" => "http://rakkit.com")
	      rescue Exception => e
	        # Most likely a 404 error
	        $stderr.puts "Unable to open url: #{url} - #{e}"
	      end
	    end
	    return url_object
	  end

	  # Get the response code of the page
	  #
	  # Example:
	  #   >> Debugger.new("http://rakkit.com").response_code
	  #   => 200 OK
	  def response_code
	    @opened_url.status.join(" ")
	  end

	  # Return the fecthed URL
	  #
	  # Example:
	  #   >> Debugger.new("rakkit.com").fetched_url
	  #   => http://rakkit.com
	  def fetched_url
	    @uri.to_s
	  end

	  # Get the canonical url of the page
	  #
	  # Example:
	  #   >> Debugger.new("http://rakkit.com").response_code
	  #   => http://rakkit.com/
	  def canonical_url
	    begin
	      canonical_uri = @uri
	      canonical_uri.path  = ''
	      canonical_uri.query = nil
	      canonical_uri = canonical_uri + "/"
	      return canonical_uri.to_s
	    rescue Exception => e
	      puts "CANONICAL ERROR: #{e}"
	      puts @uri.inspect.to_s
	    end
	  end
	  
	  # loads the Hpricot XML object if it hasn't already been loaded
	  def page
	    @page ||= Nokogiri::HTML(@opened_url)
	  end

	  # Get the RSS Feed URL
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").rss_feed_url
	  #   => http://wearepandr.com/feed
	  def rss_feed_url
	    rss_url = page.search("link[@type='application/rss+xml']")
	    rss_url = rss_url.length == 0 ? nil : rss_url.first['href']

	    rss_url = Debugger.stitch_to_make_absolute(canonical_url, rss_url) if Debugger.relative?(rss_url)
	    return rss_url.to_s
	  end

	  # Get the Atom Feed URL
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").atom_feed_url
	  #   => http://wearepandr.com/feed
	  def atom_feed_url
	    atom_url = page.search("link[@type='application/atom+xml']")
	    atom_url = atom_url.length == 0 ? nil : atom_url.first['href']

	    atom_url = Debugger.stitch_to_make_absolute(canonical_url, atom_url) if Debugger.relative?(atom_url)
	    return atom_url.to_s
	  end

	  # Get the FEED URL, no matter if it's the Atom URL or the RSS URL
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").feed_url
	  #   => http://wearepandr.com/feed
	  def feed_url
	    if rss_feed_url != '' || atom_feed_url != ''
	      feed_url = rss_feed_url != '' ? rss_feed_url : atom_feed_url
	      
	      if Debugger.relative?(feed_url)
	        feed_url = Debugger.stitch_to_make_absolute(canonical_url, feed_url)
	      else
	        feed_url = feed_url
	      end

	    else
	      feed_url = nil
	    end
	  end

	  # Return some meta info about the page
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").scrape_info
	  #   => {:response_code => "200 OK",
	  #       :fetched_url => "http://wearepandr.com",
	  #       :canonical_url => "http://wearepandr.com/",
	  #       :feed_url => "http://wearepandr.com/feed"}
	  def scrape_info
	    return {:response_code => response_code,
	            :fetched_url => fetched_url,
	            :canonical_url => canonical_url,
	            :feed_url => feed_url}  
	  end

	  # Get the page title
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").title
	  #   => Web Design Norwich and Norwich Ruby on Rails Web Development in Norfolk |  PANDR
	  def title
	    title = page.css('title')[0].inner_html.strip
	    title = title == '' ? nil : title
	    return title
	  end

	  # Get the page description
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").description
	  #   => A custom Web Design Norwich and Norwich Ruby on Rails Web Development agency based in Norfolk, UK
	  def description
	    description = page.css("meta[name='description']/@content").inner_html.strip
	    description = description == '' ? nil : description
	    return description
	  end

	  # Get the page meta data in a hash, title and description.
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").meta_data
	  #   => {:title => "Web Design Norwich and Norwich Ruby on Rails Web Development in Norfolk |  PANDR",
	  # 	  :description => "A custom Web Design Norwich and Norwich Ruby on Rails Web Development agency based in Norfolk, UK"}
	  def meta_data
	    return {:title => title,
	            :description => description}
	  end

	  # Get the music links from the feed found on the page
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").music_from_feed
	  #   => ["http://wearepandr.com/track_1.mp3", "http://wearepandr.com/track_2.mp3", "http://wearepandr.com/track_3.mp3"]
	  #
	  # Arguments:
	  #   file_types: [Array]
	  def music_from_feed(file_types=FILE_TYPES)
	    links = []
	    if !feed_url.nil?
	     @feed ||= Nokogiri::XML(open(feed_url))
	     @feed.encoding = 'utf-8'
	     channel = @feed.search('//channel')

	     # If the blog isn't set up with channels then we can 
	     # search the data we have for all links that end in .mp3 x
	     if !channel.empty?
	       items = @feed.search("//channel/item")
	       items.each do |item|
	         enclosures = item.search("//channel/item/enclosure")
	          enclosures.each do |enclosure|
	            enclosure_file = enclosure['url'].to_s[-4,4]
	            links << enclosure['url'] if file_types.include?(enclosure_file)
	          end
	        end
	      end
	    end
	    links = links.uniq
	    return links.compact
	  end

	  # Get the music links from the page html
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").music_from_html
	  #   => ["http://wearepandr.com/track_1.mp3", "http://wearepandr.com/track_2.mp3", "http://wearepandr.com/track_3.mp3"]
	  #
	  # Arguments:
	  #   file_types: [Array]
	  def music_from_html(file_types=FILE_TYPES)
	    links = []
	    
	    page_links.each do |track|
	      track_file = track['href'].to_s[-4,4]
	      
	      if file_types.include?(track_file)
	        links << track["href"]
	      end
	    end
	    links = links.uniq
	    return links.compact
	  end

	  # Get the soundcloud music links from the page html
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").music_from_soundcloud
	  #   => ["http://api.soundcloud.com/playlists/2153957", "http://api.soundcloud.com/playlists/2153958"]
	  def music_from_soundcloud
	    links = []
	    @html_url ||= Nokogiri::HTML(open(@uri))
	    @html_url.search("//iframe", "//param").each do |url|
	      object_url = url["src"] || url["value"]
	      links << Debugger.get_soundcloud_url(object_url)
	    end
	    links = links.uniq
	    return links.compact
	  end

	  # Get the internal page links from the page
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").internal_links
	  #   => ["http://wearepandr.com/about", "http://wearepandr.com/blog"]
	  def internal_links
	    links = []
	    current_host = @uri.host

	    page_links.each do |link|
	      
	      # Remove anchors from links

	      new_link = link['href'].nil? ? nil : link['href'].split("#")[0]
	      
	      if !new_link.nil? && !new_link.strip.empty? && !Debugger.mailto_link?(new_link)
	        
	        new_link = Debugger.make_absolute(new_link)

	        if new_link != nil
	          
	          # Check to see if the URL is still from the current site
	          #
	          if current_host == Addressable::URI.parse(new_link).host
	            links << new_link
	          end

	        end
	      end
	    end
	    links = links.uniq
	    return links.compact
	  end

	  # Get all the links from the page
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").page_links
	  #   => ["http://wearepandr.com/about", "http://google.com", "http://yahoo.com"]
	  def page_links
	    @html_url ||= Nokogiri::HTML(open(@uri))

	    links = @html_url.search("//a")
	    return links
	  end

	  # Get all the links from the page
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").host
	  #   => wearepandr.com
	  def host
	    Addressable::URI.parse(@uri).host  
	  end

	  # Get the pages content type
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").content_type
	  #   => text/html
	  def content_type
	    @opened_url.content_type
	  end

	  # Get the pages charset
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").charset
	  #   => utf-8
	  def charset
	    @opened_url.charset
	  end

	  # Get the pages content encoding
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").content_encoding
	  #   => []
	  def content_encoding
	    @opened_url.content_encoding
	  end

	  # Get the pages last modified date
	  #
	  # Example:
	  #   >> Debugger.new("http://wearepandr.com").last_modified
	  #   => 
	  def last_modified
	    @opened_url.last_modified
	  end

	  # Get the user agent
	  #
	  # Example:
	  #   >> Debugger.user_agent("PANDR")
	  #   => PANDR/V0.1
	  #
	  # Arguments:
	  #   ua: (String)
	  def self.user_agent(ua="Rakkit")
	    "#{ua}/V#{Debugher::VERSION}"
	  end

	  # Get the current version
	  #
	  # Example:
	  #   >> Debugger.version
	  #   => V0.1
	  def self.version
	    "V#{Debugher::VERSION}"
	  end

	  # Check if a URL is relative or not
	  #
	  # Example:
	  #   >> Debugger.relative?("http://wearepandr.com")
	  #   => false
	  #
	  # Arguments:
	  #   url: (String)
	  def self.relative?(url)
	    begin
	      @addressable_url = Addressable::URI.parse(url)
	      return @addressable_url.relative?
	    rescue
	      return false
	    end
	  end

	  # Make a URL absolute
	  #
	  # Example:
	  #   >> Debugger.make_absolute("/about", "http://wearepandr.com")
	  #   => http://wearepandr.com/about
	  #
	  # Arguments:
	  #   url: (String)
	  #   base_url: (String)
	  def self.make_absolute(url, base_url=nil)
	    if Debugger.relative?(url)
	      begin
	        if !base_url.nil?
	          base_url = Debugger.new(base_url).canonical_url
	        else
	          base_url = canonical_url
	        end

	        url = Debugger.stitch_to_make_absolute(base_url, url)
	      rescue Exception => e
	        url = nil
	        $stderr.puts "Debugger Error: #{url} - #{e}"
	        puts "ERROR: Could not make this URL absolute. Set to nil."
	      end
	    end
	    return url
	  end

	  # Stitch two strings together to make a single absolute url
	  #
	  # Example:
	  #   >> Debugger.stitch_to_make_absolute("http://wearepandr.com/", "/about")
	  #   => http://wearepandr.com/about
	  #
	  # Arguments:
	  #   canonical_url: (String)
	  #   path: (String)
	  def self.stitch_to_make_absolute(canonical_url, path)
	    canonical_url.chomp("/") + path
	  end

	  # Check if a string is a mailto link
	  #
	  # Example:
	  #   >> Debugger.mailto_link?("mailto:pete@wearepandr.com")
	  #   => true
	  #
	  # Arguments:
	  #   url: (String)
	  def self.mailto_link?(url)
	    url[0..5] == "mailto"
	  end

	  # Extract the URL element of a soundcloud embed in order to grab the link to the track.
	  #
	  # Example:
	  #   >> Debugger.get_soundcloud_url("https://w.soundcloud.com/player/?url=http%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F59422468")
	  #   => http://api.soundcloud.com/tracks/59422468
	  #
	  # Arguments:
	  #   url: (String)
	  def self.get_soundcloud_url(url)
	    begin
	      uri = URI.parse(url)
	      new_url = uri.query.split("&").reject { |q| q[0..2] != "url"}[0]
	      new_url = CGI.unescape(new_url[4..new_url.length])

	      if Debugger.soundcloud_url?(new_url)
	        return new_url
	      end
	    rescue
	      $stderr.puts "Bad URL - Soundcloud URL's don't cause errors so safe to assume it's not a Soundcloud link."
	    end
	  end

	  # Check if a string is a Soundcloud URL
	  #
	  # Example:
	  #   >> Debugger.soundcloud_url?("http://api.soundcloud.com/tracks/59422468")
	  #   => http://api.soundcloud.com/tracks/59422468
	  #
	  # Arguments:
	  #   url: (String)
	  def self.soundcloud_url?(url)
	    url.include?("api.soundcloud.com")
	  end

	  # Check if a url is a valid url
	  #
	  # Example:
	  #   >> Debugger.valid_url?("http://wearepandr.com")
	  #   => true
	  #
	  # Arguments:
	  #   url: (String)
	  def self.valid_url?(url)
	    !(url =~ URI::regexp).nil?
	  end
	end
end