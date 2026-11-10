# frozen_string_literal: true

module Raintron
  # Opens a Raindeer app in a native desktop window. The server runs as a real forked
  # child process, not a Thread inside this same process: webview_ruby's native run
  # loop holds Ruby's GVL for as long as the window is open, which would starve a
  # Thread-based server; a separate OS process sidesteps that entirely. `fork` (never
  # Process.spawn of a separate script path) is mandatory once packed by Tebako, since
  # a resolvable script path for a second process to exec doesn't exist inside a
  # packed image -- the whole app lives in a single executable.
  #
  # The window opens straight away, on Raindown's rain cloud while the server boots:
  # loading.html, self-contained and opened as a data: URL, as nothing's serving yet,
  # with the app's URL as its fragment. The page polls that URL itself and switches to
  # the app once it answers -- polling can't happen here, since the window's run loop
  # holds the GVL from the moment it opens.
  class Launcher
    LOADING_PAGE = File.expand_path('loading.html', __dir__)

    def initialize(title:, size: [900, 600], host: '127.0.0.1', port: 4133, app_root: Dir.pwd, &server_block)
      @title = title
      @width, @height = size
      @host = host
      @port = port
      @app_root = app_root
      @server_block = server_block
    end

    def run
      start_server
      open_window
    ensure
      stop_server
    end

    # Public (and independently callable) so the server half can be exercised
    # headlessly in tests, with no window and no webview_ruby involved at all.
    def start_server
      # Set before fork, unconditionally (not just when packed): the child inherits
      # it via fork's memory copy, and Shims::PwdOverride uses it to answer Dir.pwd
      # correctly regardless of what directory bin/desktop was actually launched from.
      ENV['RAINTRON_APP_ROOT'] ||= @app_root
      @pid = fork do
        Raintron::Shims.apply!(packed: Raintron.packed?)
        @server_block.call
      end
    end

    # Base64, not percent-encoding, so the page's own # characters (its colours) can't
    # be read as the start of the fragment.
    def loading_url
      "data:text/html;charset=utf-8;base64,#{[File.read(LOADING_PAGE)].pack('m0')}#http://#{@host}:#{@port}/"
    end

    def open_window
      # Required only here, only in the parent, only after fork: macOS's Cocoa/WebKit
      # frameworks (which this pulls in) are not fork-safe, so the child must never
      # have loaded them.
      require 'webview_ruby'

      webview = WebviewRuby::Webview.new
      webview.set_title(@title)
      webview.set_size(@width, @height)
      hide_titlebar(webview) if AppConfig.titlebar(app_root: @app_root) == 'hidden'
      webview.navigate(loading_url)
      webview.run
      webview.destroy
    end

    def stop_server
      return unless @pid

      Process.kill('TERM', @pid)
      Process.wait(@pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end

    private

    def hide_titlebar(webview)
      require_relative '../window_chrome/window_chrome'
      WindowChrome.hide_titlebar(webview)
    end
  end
end
