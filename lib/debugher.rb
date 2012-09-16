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

	  def response_code
	    @opened_url.status.join(" ")
	  end

	  def fetched_url
	    @uri.to_s
	  end

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

	  # Searches the blog xml for the blog url
	  def rss_feed_url
	    rss_url = page.search("link[@type='application/rss+xml']")
	    rss_url = rss_url.length == 0 ? nil : rss_url.first['href']

	    rss_url = Debugger.stitch_to_make_absolute(canonical_url, rss_url) if Debugger.relative?(rss_url)
	    return rss_url.to_s
	  end

	  def atom_feed_url
	    atom_url = page.search("link[@type='application/atom+xml']")
	    atom_url = atom_url.length == 0 ? nil : atom_url.first['href']

	    atom_url = Debugger.stitch_to_make_absolute(canonical_url, atom_url) if Debugger.relative?(atom_url)
	    return atom_url.to_s
	  end

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

	  def scrape_info
	    return {:response_code => response_code,
	            :fetched_url => fetched_url,
	            :canonical_url => canonical_url,
	            :feed_url => feed_url}  
	  end

	  # Searches the blog xml for the blog title
	  def title
	    title = page.css('title')[0].inner_html.strip
	    title = title == '' ? nil : title
	    return title
	  end

	  ###
	  # WARNING: DIFFICULT TO DO - NO STANDARD APPROACH BY SITES
	  ###
	  def description
	    description = page.css("meta[name='description']/@content").inner_html.strip
	    description = description == '' ? nil : description
	    return description
	  end

	  def meta_data
	    return {:title => title,
	            :description => description}
	  end

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

	  # Scrapes the html for any links that may not appear in the xml
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

	  def page_links
	    @html_url ||= Nokogiri::HTML(open(@uri))

	    links = @html_url.search("//a")
	    return links
	  end

	  def host
	    Addressable::URI.parse(@uri).host  
	  end

	  def content_type
	    @opened_url.content_type
	  end

	  def charset
	    @opened_url.charset
	  end

	  def content_encoding
	    @opened_url.content_encoding
	  end

	  def last_modified
	    @opened_url.last_modified
	  end

	  # Self Methods
	  #
	  def self.user_agent
	    "Rakkit/V#{Debugher::VERSION}"
	  end

	  def self.version
	    "V#{Debugher::VERSION}"
	  end

	  # Checks if a URL is relative or not?
	  #
	  def self.relative?(url)
	    begin
	      @addressable_url = Addressable::URI.parse(url)
	      return @addressable_url.relative?
	    rescue
	      return false
	    end
	  end

	  # Check if URL is relative or not.
	  #
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

	  # 
	  def self.stitch_to_make_absolute(canonical_url, path)
	    canonical_url.chomp("/") + path
	  end

	  def self.mailto_link?(url)
	    url[0..5] == "mailto"
	  end

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

	  def self.soundcloud_url?(url)
	    url.include?("api.soundcloud.com")
	  end

	  def self.valid_url?(url)
	    !(url =~ URI::regexp).nil?
	  end
	end
end