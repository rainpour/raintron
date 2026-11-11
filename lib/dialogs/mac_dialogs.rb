# frozen_string_literal: true

require_relative '../window_chrome/mac_chrome'

module Raintron
  module Dialogs
    # macOS's dialogs, made with AppKit, as the window's chrome is.
    module MacDialogs
      ObjC = WindowChrome::MacChrome::ObjC
      MODAL_RESPONSE_OK = 1

      module_function

      # An NSOpenPanel for one folder, in front of the app's windows, which can make a new one, and the path of the folder
      # chosen, or nil.
      def pick_folder
        panel = ObjC.send_for_pointer(ObjC.get_class('NSOpenPanel'), ObjC.selector('openPanel'))
        { 'setCanChooseDirectories:' => true, 'setCanChooseFiles:' => false, 'setAllowsMultipleSelection:' => false,
          'setCanCreateDirectories:' => true }.each { |message, value| ObjC.send_bool(panel, ObjC.selector(message), value) }
        return unless ObjC.send_for_long(panel, ObjC.selector('runModal')) == MODAL_RESPONSE_OK

        path = ObjC.send_for_pointer(ObjC.send_for_pointer(panel, ObjC.selector('URL')), ObjC.selector('path'))
        ObjC.send_for_string(path, ObjC.selector('UTF8String'))
      end
    end
  end
end
