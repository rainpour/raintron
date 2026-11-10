# frozen_string_literal: true

require 'ffi'
require 'json'

module Raintron
  # A window without a title bar, like Obsidian's, on macOS: the page runs under a transparent title bar with its
  # title hidden, leaving only the traffic lights over it. The page takes the title bar's place, so it's told with
  # window.raintron = { titlebar: 'hidden' }, and calls window.raintronDragWindow() on a mouse down where the window
  # should be dragged from, as WebKit takes the mouse events the title bar had.
  #
  # Required only by Launcher#open_window, after webview_ruby, in the window's process. Elsewhere the title bar stays.
  module WindowChrome
    FULL_SIZE_CONTENT_VIEW = 1 << 15
    TITLE_HIDDEN = 1

    # The Objective-C runtime, with objc_msgSend typed for each shape of message sent here.
    module ObjC
      extend FFI::Library

      ffi_lib '/usr/lib/libobjc.A.dylib'
      attach_function :get_class, :objc_getClass, [:string], :pointer
      attach_function :selector, :sel_registerName, [:string], :pointer
      attach_function :send_for_pointer, :objc_msgSend, %i[pointer pointer], :pointer
      attach_function :send_for_ulong, :objc_msgSend, %i[pointer pointer], :ulong
      attach_function :send_pointer, :objc_msgSend, %i[pointer pointer pointer], :void
      attach_function :send_ulong, :objc_msgSend, %i[pointer pointer ulong], :void
      attach_function :send_bool, :objc_msgSend, %i[pointer pointer bool], :void
      attach_function :send_long, :objc_msgSend, %i[pointer pointer long], :void
    end

    module_function

    def hide_titlebar(webview)
      return unless RbConfig::CONFIG['host_os'].include?('darwin')

      window = native_window(webview)
      style = ObjC.send_for_ulong(window, ObjC.selector('styleMask'))
      ObjC.send_ulong(window, ObjC.selector('setStyleMask:'), style | FULL_SIZE_CONTENT_VIEW)
      ObjC.send_bool(window, ObjC.selector('setTitlebarAppearsTransparent:'), true)
      ObjC.send_long(window, ObjC.selector('setTitleVisibility:'), TITLE_HIDDEN)
      webview.bind('raintronDragWindow') { |*| drag(window) }
      webview.init("window.raintron = #{JSON.generate(titlebar: 'hidden')}")
    end

    # Drags the window with the mouse down that's being handled, as a title bar would.
    def drag(window)
      application = ObjC.send_for_pointer(ObjC.get_class('NSApplication'), ObjC.selector('sharedApplication'))
      event = ObjC.send_for_pointer(application, ObjC.selector('currentEvent'))
      ObjC.send_pointer(window, ObjC.selector('performWindowDragWithEvent:'), event) unless event.null?
    end

    # The NSWindow. webview_ruby keeps webview.h's handle to itself and doesn't bind webview_get_window, which its
    # library exports, so it's bound here.
    def native_window(webview)
      WebviewRuby.attach_function(:webview_get_window, [:pointer], :pointer) unless WebviewRuby.respond_to?(:webview_get_window)
      WebviewRuby.webview_get_window(webview.instance_variable_get(:@window))
    end
  end
end
