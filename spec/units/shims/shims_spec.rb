# frozen_string_literal: true

RSpec.describe Raintron::Shims do
  after { ENV.delete('RAINTRON_FORCE_PACKED') }

  describe '.packed?' do
    it 'is true when RAINTRON_FORCE_PACKED is set, regardless of path' do
      ENV['RAINTRON_FORCE_PACKED'] = '1'
      allow(described_class).to receive(:__dir__).and_return('/usr/local/lib/ruby/gems/raintron/lib/shims')

      expect(described_class.packed?).to be true
    end

    it 'is true when the gem is loaded from inside a Tebako-packed path' do
      allow(described_class).to receive(:__dir__).and_return('/__tfs__/lib/ruby/gems/3.4.0/gems/raintron-0.1.0/lib/shims')

      expect(described_class.packed?).to be true
    end

    it 'is false on an ordinary install path' do
      allow(described_class).to receive(:__dir__).and_return('/usr/local/lib/ruby/gems/raintron/lib/shims')

      expect(described_class.packed?).to be false
    end
  end

  describe '.apply!' do
    it 'requires the packed fs shim only when packed: true' do
      expect(described_class).to receive(:require_relative).with('packed_fs_shim')

      described_class.apply!(packed: true)
    end

    it 'does not require the packed fs shim when packed: false' do
      expect(described_class).not_to receive(:require_relative).with('packed_fs_shim')

      described_class.apply!(packed: false)
    end

    it 'defaults packed: to .packed? when not given explicitly' do
      allow(described_class).to receive(:packed?).and_return(true)
      expect(described_class).to receive(:require_relative).with('packed_fs_shim')

      described_class.apply!
    end
  end
end
