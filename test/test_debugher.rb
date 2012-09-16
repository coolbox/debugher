require './lib/debugher'
require 'test/unit'
require 'rack/test'

ENV['RACK_ENV'] = 'test'

class DebugherTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Debugher
  
  def test_initialize
    @page = Debugger.new("http://wearepandr.com/")
    
    assert_equal @page.url, "http://wearepandr.com/"
  end

  def test_rss_feed_url
    @page = Debugger.new("http://funtofunky.wordpress.com/")
    assert_equal @page.rss_feed_url, "http://funtofunky.wordpress.com/feed/"

    @page = Debugger.new("http://blog.iso50.com/")
    assert_equal @page.rss_feed_url, "http://blog.iso50.com/feed/"
  end

  def test_atom_feed_url
    @page = Debugger.new("http://wearepandr.com/")
    assert_equal @page.atom_feed_url, "http://wearepandr.com/feed"

    @page = Debugger.new("http://thefourohfive.com/")
    assert_equal @page.atom_feed_url, "http://thefourohfive.com/feed"
  end

  def test_feed_url
    # Atom Feed
    @page = Debugger.new("http://wearepandr.com/")
    assert_equal @page.feed_url, "http://wearepandr.com/feed"    

    # RSS Feed
    @page = Debugger.new("http://funtofunky.wordpress.com")
    assert_equal @page.feed_url, "http://funtofunky.wordpress.com/feed/"
  end

  def test_scrape_info
    @page = Debugger.new("http://rakkit.com/about")
    @scrape_info = @page.scrape_info

    assert_equal '200 OK', @scrape_info[:response_code]
    assert_equal 'http://rakkit.com/about', @scrape_info[:fetched_url]
    assert_equal 'http://rakkit.com/', @scrape_info[:canonical_url]
    assert_equal nil, @scrape_info[:feed_url]
  end

  def test_meta_data
    @page = Debugger.new("http://rakkit.com")
    @meta = @page.meta_data

    assert_equal 'The latest new music from websites, artists and labels you love | Rakkit', @meta[:title]
    assert_equal 'The Social link between new music and the fans.', @meta[:description]
  end

  def test_music_from_feed
    @page = Debugger.new("http://blog.iso50.com")
    @music_links = @page.music_from_feed

    assert @music_links.kind_of?(Array)
  end

  def test_music_from_html
    @page = Debugger.new("http://blog.iso50.com")
    @music_links = @page.music_from_html

    assert @music_links.kind_of?(Array)
  end

  def test_music_from_soundcloud
    @page = Debugger.new("http://funtofunky.wordpress.com/")
    @music_links = @page.music_from_soundcloud

    assert @music_links.kind_of?(Array)
  end

  def test_page_links
    @page = Debugger.new("http://funtofunky.wordpress.com/")
    @internal_links = @page.internal_links

    assert @internal_links.kind_of?(Array)
  end

  def test_valid_url?
    @valid_url = Debugger.valid_url?("http://funtofunky.wordpress.com/")
    assert_equal @valid_url, true

    @valid_url = Debugger.valid_url?("blah blah blah")
    assert_equal @valid_url, false
  end

  def test_host
    @page = Debugger.new("http://funtofunky.wordpress.com/")
    assert_equal @page.host, "funtofunky.wordpress.com"
  end

  def test_content_type
    @page = Debugger.new("http://wearepandr.com")
    assert_equal @page.content_type, "text/html"
  end

  def test_charset
    @page = Debugger.new("http://wearepandr.com")
    assert_equal @page.charset, "utf-8"
  end

  def test_content_encoding
    # Need to find better examples of this
    @page = Debugger.new("http://wearepandr.com")
    assert_equal @page.content_encoding, []
  end

  def test_last_modified
    # Need to find better examples of this
    @page = Debugger.new("http://wearepandr.com")
    assert_equal @page.last_modified, nil
  end

  # Self Methods
  #
  def test_user_agent
    @ua = Debugger.user_agent
    assert_equal @ua, "Rakkit/V#{Debugher::VERSION}"

    @ua = Debugger.user_agent("PANDR")
    assert_equal @ua, "PANDR/V#{Debugher::VERSION}"
  end

  def test_version
    @version = Debugger.version

    # Enough of a test that we're getting the Version #
    assert_equal @version, "V#{Debugher::VERSION}"
  end

  def test_mail_to_link?
    @url = "http://wearepandr.com"
    assert_equal Debugger.mailto_link?(@url), false

    @url = "mailto:pete@wearepandr.com"
    assert_equal Debugger.mailto_link?(@url), true
  end

  def test_relative?
    @url = "/"
    assert_equal Debugger.relative?(@url), true

    @url = "/about"
    assert_equal Debugger.relative?(@url), true

    @url = "http://wearepandr.com"
    assert_equal Debugger.relative?(@url), false

    @url = "http://wearepandr.com/"
    assert_equal Debugger.relative?(@url), false

    @url = "http://staff.wearepandr.com"
    assert_equal Debugger.relative?(@url), false
  end

  def test_make_absolute
    @absolute = Debugger.make_absolute("/about", "http://blog.iso50.com")
    assert_equal @absolute, "http://blog.iso50.com/about"

    @absolute = Debugger.make_absolute("/about", "http://blog.iso50.com/")
    assert_equal @absolute, "http://blog.iso50.com/about"
  end

  def test_get_soundcloud_url
    @soundcloud_embed = "https://w.soundcloud.com/player/?url=http%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F59422468"
    assert_equal Debugger.get_soundcloud_url(@soundcloud_embed), "http://api.soundcloud.com/tracks/59422468"

    @soundcloud_embed = "https://w.soundcloud.com/player/?url=http%3A%2F%2Fapi.soundcloud.com%2Fplaylists%2F2153957"
    assert_equal Debugger.get_soundcloud_url(@soundcloud_embed), "http://api.soundcloud.com/playlists/2153957"

    @soundcloud_embed = "http://wearepandr.com"
    assert_equal Debugger.get_soundcloud_url(@soundcloud_embed), nil
  end

  def test_soundcloud_url?
    @url = "http://wearepandr.com"
    assert_equal Debugger.soundcloud_url?(@url), false

    @url = "http://api.soundcloud.com/playlists/2153957"
    assert_equal Debugger.soundcloud_url?(@url), true

    # A further addition to the method could be to test that there
    # is a unique id on the end of the url.
  end
end