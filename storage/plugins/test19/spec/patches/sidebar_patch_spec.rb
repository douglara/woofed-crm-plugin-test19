require 'rails_helper'

RSpec.describe 'Sidebar patch for test19 plugin' do
  let(:original) { Rails.root.join('app/views/layouts/shared/_sidebar.html.erb').read }

  before { Plugins::FilePatch.clear_registry! }
  after  { Plugins::FilePatch.clear_registry! }

  it 'adds the world_clock menu item' do
    load Rails.root.join('storage/plugins/test19/app/views/layouts/shared/_sidebar.html.erb')
    result = Plugins::FilePatch.apply('app/views/layouts/shared/_sidebar.html.erb', original)

    expect(result).to include('account_world_clock_index_path(Current.account)')
    expect(result).to include("t('plugins.test19.world_clock')")
    expect(result).to include('globe')
    expect(result).to include('world_clock')
  end

  it 'does not modify the original file' do
    original_content = Rails.root.join('app/views/layouts/shared/_sidebar.html.erb').read
    expect(original_content).not_to include('world_clock')
    expect(original_content).not_to include('plugins.test19')
  end
end
