# frozen_string_literal: true

require_relative '../../../lib/dialogs/dialogs'

RSpec.describe Raintron::Dialogs do
  # A web view keeping its bound calls, to call as the page would, and the scripts it's given.
  let(:webview) do
    Class.new do
      def bindings = @bindings ||= {}
      def scripts = @scripts ||= []
      def evaluated = @evaluated ||= []
      def bind(name, &block) = bindings[name] = block
      def init(script) = scripts << script
      def eval(script) = evaluated << script
    end.new
  end
  let(:picker) { Module.new }

  before { allow(described_class).to receive(:platform_dialogs).and_return(picker) }

  it 'tells the page it can pick a folder, and answers with the folder picked' do
    picker.define_singleton_method(:pick_folder) { '/Users/me/dev' }
    described_class.bind(webview)
    webview.bindings['raintronPickFolder'].call

    expect(webview.scripts).to eq(['window.raintron = Object.assign(window.raintron ?? {}, { pickFolder: true })'])
    expect(webview.evaluated).to eq(['window.raintronFolderPicked?.("/Users/me/dev")'])
  end

  it 'answers null when the picker is cancelled or fails, rather than raising, which would close the window' do
    picker.define_singleton_method(:pick_folder) { raise 'No AppKit' }
    described_class.bind(webview)
    webview.bindings['raintronPickFolder'].call

    expect(webview.evaluated).to eq(['window.raintronFolderPicked?.(null)'])
  end

  it 'binds nothing where there are no dialogs' do
    allow(described_class).to receive(:platform_dialogs).and_return(nil)
    described_class.bind(webview)

    expect(webview.bindings).to be_empty
  end
end
