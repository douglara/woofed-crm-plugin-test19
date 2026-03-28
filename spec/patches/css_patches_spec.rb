require "rails_helper"

RSpec.describe "ai_features CSS patches" do
  before { Plugins::FilePatch.clear_registry! }
  after  { Plugins::FilePatch.clear_registry! }

  describe "application.tailwind.css" do
    let(:original) { Rails.root.join("app/assets/stylesheets/application.tailwind.css").read }

    it "replaces #5440D2 with #14532D in label-v4" do
      load Rails.root.join("storage/plugins/ai_features/app/assets/stylesheets/application.tailwind.css")
      result = Plugins::FilePatch.apply("app/assets/stylesheets/application.tailwind.css", original)
      expect(result).to include("#14532D")
      expect(result).not_to include("#5440D2")
    end
  end

  describe "w-btn-outline.scss" do
    let(:original) { Rails.root.join("app/assets/stylesheets/commons/w-btn-outline.scss").read }

    it "replaces purple with green" do
      load Rails.root.join("storage/plugins/ai_features/app/assets/stylesheets/commons/w-btn-outline.scss")
      result = Plugins::FilePatch.apply("app/assets/stylesheets/commons/w-btn-outline.scss", original)
      expect(result).to include("#15803D")
      expect(result).to include("#BBF7D0")
      expect(result).not_to include("#6857D9")
    end
  end

  describe "fullcalendar.scss" do
    let(:original) { Rails.root.join("app/assets/stylesheets/fullcalendar.scss").read }

    it "replaces all purple brand colors" do
      load Rails.root.join("storage/plugins/ai_features/app/assets/stylesheets/fullcalendar.scss")
      result = Plugins::FilePatch.apply("app/assets/stylesheets/fullcalendar.scss", original)
      expect(result).to include("--fc-button-hover-text-color: #15803D")
      expect(result).to include("--fc-today-bg-color: #F0FDF4")
      expect(result).not_to include("#6857D9")
    end
  end

  describe "flatpickr-custom.scss" do
    let(:original) { Rails.root.join("app/assets/stylesheets/flatpickr-custom.scss").read }

    it "replaces all purple colors with green" do
      load Rails.root.join("storage/plugins/ai_features/app/assets/stylesheets/flatpickr-custom.scss")
      result = Plugins::FilePatch.apply("app/assets/stylesheets/flatpickr-custom.scss", original)
      expect(result).not_to include("#6857d9")
      expect(result).not_to include("#8686e8")
      expect(result).not_to include("#edf1fd")
      expect(result).not_to include("rgba(104, 87, 217")
      expect(result).to include("#15803d")
      expect(result).to include("#dcfce7")
    end
  end
end
