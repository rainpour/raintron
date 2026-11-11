# frozen_string_literal: true

require 'fileutils'
require 'socket'
require 'uri'

module Raintron
  # The app in a browser the machine already has, where it has no web view for a native window, like Linux without
  # WebKitGTK, so the packed app needs nothing installed beside it. It opens once the server answers, without the rain
  # cloud, as Chromium won't let a page at a data: URL reach the server on 127.0.0.1. A Chromium-based browser opens it as
  # an app, in a window without tabs or an address bar, with a profile of the app's own, so the browser's process is the
  # window's, and ends when it closes. Without one, the default browser opens it in a tab.
  class BrowserWindow
    APP_BROWSERS = %w[google-chrome google-chrome-stable chromium chromium-browser brave-browser microsoft-edge].freeze
    OPENERS = %w[xdg-open open].freeze
    SERVER_WAIT_SECONDS = 30

    def initialize(title:, app_url:, size:)
      @title = title
      @app_url = app_url
      @width, @height = size
    end

    # Opens the window, returning true once it's closed, or false straight away for a tab, whose closing can't be seen.
    def run
      browser = executable(APP_BROWSERS)
      opener = executable(OPENERS) unless browser
      raise Error, "#{@title} needs WebKitGTK, a Chromium-based browser or xdg-open to open its window" unless browser || opener

      wait_for_server
      return open_tab(opener) unless browser

      Process.wait(Process.spawn(browser, *app_args, out: File::NULL, err: File::NULL))
      true
    end

    private

    def app_args
      ["--app=#{@app_url}", "--user-data-dir=#{profile}", "--window-size=#{@width},#{@height}", '--no-first-run',
       '--no-default-browser-check']
    end

    # The app's own browser profile, which keeps its window's size and its storage from one launch to the next.
    def profile
      data = ENV.fetch('XDG_DATA_HOME', File.join(Dir.home, '.local', 'share'))
      File.join(data, 'raintron', @title.downcase.gsub(/[^a-z0-9]+/, '-')).tap { FileUtils.mkdir_p(it) }
    end

    def open_tab(opener)
      Process.detach(Process.spawn(opener, @app_url, out: File::NULL, err: File::NULL))
      false
    end

    def wait_for_server
      uri = URI(@app_url)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + SERVER_WAIT_SECONDS
      begin
        Socket.tcp(uri.host, uri.port, connect_timeout: 1).close
      rescue SystemCallError
        raise if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.1
        retry
      end
    end

    # The first of the names that's an executable on the PATH, as a path.
    def executable(names)
      directories = ENV.fetch('PATH', '').split(File::PATH_SEPARATOR)
      names.product(directories).map { |name, directory| File.join(directory, name) }
           .find { File.file?(it) && File.executable?(it) }
    end
  end
end
