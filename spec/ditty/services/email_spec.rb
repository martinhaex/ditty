# frozen_string_literal: true

require 'spec_helper'
require 'ditty/services/email'

describe Ditty::Services::Email do
  before(:each) do
    described_class.remove_instance_variable :@config if described_class.instance_variable_defined? :@config
  end

  context 'config!' do
    it 'configures the Mail gem' do
      expect(Mail).to receive(:defaults)
      described_class.config!
    end

    it 'uses the default settings' do
      expect(described_class).to receive(:default).and_call_original
      described_class.config!
    end
  end

  context 'deliver!' do
    it 'autoloads a ditty email from a symbol' do
      mail = Mail.new
      expect(mail).to receive(:deliver!)
      described_class.deliver(:base, 'test@mail.com', locals: { content: 'content' }, mail: mail)
    end

    it 'sends a mail object' do
      mail = Mail.new
      expect(mail).to receive(:deliver!)
      described_class.deliver(mail)
    end
  end
end
