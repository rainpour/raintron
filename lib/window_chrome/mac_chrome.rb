# frozen_string_literal: true

require 'ffi'

module Raintron
  module WindowChrome
    # macOS's window without a title bar: the page runs under a transparent title bar with its title hidden, leaving only
    # the traffic lights over it, so the page draws no window controls of its own.
    module MacChrome
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

      def window_controls?
        false
      end

      # Hides the NSWindow's title bar.
      def hide_titlebar(window)
        style = ObjC.send_for_ulong(window, ObjC.selector('styleMask'))
        ObjC.send_ulong(window, ObjC.selector('setStyleMask:'), style | FULL_SIZE_CONTENT_VIEW)
        ObjC.send_bool(window, ObjC.selector('setTitlebarAppearsTransparent:'), true)
        ObjC.send_long(window, ObjC.selector('setTitleVisibility:'), TITLE_HIDDEN)
      end

      # Drags the window with the mouse down that's being handled, as a title bar would.
      def drag(window)
        application = ObjC.send_for_pointer(ObjC.get_class('NSApplication'), ObjC.selector('sharedApplication'))
        event = ObjC.send_for_pointer(application, ObjC.selector('currentEvent'))
        ObjC.send_pointer(window, ObjC.selector('performWindowDragWithEvent:'), event) unless event.null?
      end
    end
  end
end
