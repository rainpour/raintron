# frozen_string_literal: true

require 'ffi'

module Raintron
  module WindowChrome
    # Linux's window without a title bar, a GtkWindow without its decorations. They're its close, minimise and maximise
    # buttons too, so the page draws its own, which call these.
    module GtkChrome
      PRIMARY_BUTTON = 1

      # GTK 3 and GDK 3, which WebKitGTK's window is made with.
      module Gtk
        extend FFI::Library

        ffi_lib 'libgtk-3.so.0', 'libgdk-3.so.0'
        attach_function :set_decorated, :gtk_window_set_decorated, %i[pointer bool], :void
        attach_function :begin_move_drag, :gtk_window_begin_move_drag, %i[pointer int int int uint32], :void
        attach_function :current_event_time, :gtk_get_current_event_time, [], :uint32
        attach_function :close, :gtk_window_close, [:pointer], :void
        attach_function :iconify, :gtk_window_iconify, [:pointer], :void
        attach_function :maximized?, :gtk_window_is_maximized, [:pointer], :bool
        attach_function :maximize, :gtk_window_maximize, [:pointer], :void
        attach_function :unmaximize, :gtk_window_unmaximize, [:pointer], :void
        attach_function :default_display, :gdk_display_get_default, [], :pointer
        attach_function :default_seat, :gdk_display_get_default_seat, [:pointer], :pointer
        attach_function :seat_pointer, :gdk_seat_get_pointer, [:pointer], :pointer
        attach_function :device_position, :gdk_device_get_position, %i[pointer pointer pointer pointer], :void
      end

      module_function

      def window_controls?
        true
      end

      def hide_titlebar(window)
        Gtk.set_decorated(window, false)
      end

      # Moves the window with the pointer, from where it is, as its title bar would.
      def drag(window)
        x = FFI::MemoryPointer.new(:int)
        y = FFI::MemoryPointer.new(:int)
        Gtk.device_position(Gtk.seat_pointer(Gtk.default_seat(Gtk.default_display)), nil, x, y)
        Gtk.begin_move_drag(window, PRIMARY_BUTTON, x.read_int, y.read_int, Gtk.current_event_time)
      end

      def close(window)
        Gtk.close(window)
      end

      def minimize(window)
        Gtk.iconify(window)
      end

      def maximize(window)
        return Gtk.unmaximize(window) if Gtk.maximized?(window)

        Gtk.maximize(window)
      end
    end
  end
end
