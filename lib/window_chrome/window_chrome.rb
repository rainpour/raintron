# frozen_string_literal: true

require 'json'

module Raintron
  # A window without a title bar, like Obsidian's, on macOS and Linux. The page takes the title bar's place, so it's
  # told with window.raintron = { titlebar: 'hidden', windowControls: }, and calls window.raintronDragWindow() on a mouse
  # down where the window should be dragged from, as WebKit takes the mouse events the title bar had. Where the window's
  # controls went with it, on Linux, windowControls is true, and the page draws its own, which call
  # window.raintronCloseWindow(), window.raintronMinimizeWindow() and window.raintronMaximizeWindow(), which unmaximizes
  # a maximized window.
  #
  # Required only by Launcher#open_window, after webview_ruby, in the window's process. Elsewhere the title bar stays.
  module WindowChrome
    CONTROLS = %i[close minimize maximize].freeze

    module_function

    def hide_titlebar(webview)
      chrome = platform_chrome
      return unless chrome

      window = native_window(webview)
      chrome.hide_titlebar(window)
      webview.bind('raintronDragWindow') { |*| chrome.drag(window) }
      bind_controls(webview, chrome, window) if chrome.window_controls?
      webview.init("window.raintron = #{JSON.generate(titlebar: 'hidden', windowControls: chrome.window_controls?)}")
    end

    def platform_chrome
      case RbConfig::CONFIG['host_os']
      when /darwin/
        require_relative 'mac_chrome'
        MacChrome
      when /linux/
        require_relative 'gtk_chrome'
        GtkChrome
      end
    end

    def bind_controls(webview, chrome, window)
      CONTROLS.each do |control|
        webview.bind("raintron#{control.capitalize}Window") { |*| chrome.public_send(control, window) }
      end
    end

    # The NSWindow or GtkWindow. webview_ruby keeps webview.h's handle to itself and doesn't bind webview_get_window,
    # which its library exports, so it's bound here.
    def native_window(webview)
      WebviewRuby.attach_function(:webview_get_window, [:pointer], :pointer) unless WebviewRuby.respond_to?(:webview_get_window)
      WebviewRuby.webview_get_window(webview.instance_variable_get(:@window))
    end
  end
end
