require 'spec_helper'
require 'money-rails/test_helpers'

describe ManageIQ::Consumption::ShowbackInputMeasure do
  before(:each) do
    ManageIQ::Consumption::ShowbackInputMeasure.delete_all
  end

  context "validations" do
    let(:showback_usage) { FactoryGirl.build(:showback_input_measure) }
    let(:event) { FactoryGirl.build(:showback_data_rollup) }

    it "has a valid factory" do
      expect(showback_usage).to be_valid
    end
    it "should ensure presence of category" do
      showback_usage.entity = nil
      expect(showback_usage).not_to be_valid
    end

    it "should ensure presence of category included in VALID_CATEGORY fail" do
      showback_usage.entity = "region"
      expect(showback_usage).to be_valid
    end

    it "should ensure presence of description" do
      showback_usage.description = nil
      showback_usage.valid?
      expect(showback_usage.errors[:description]).to include "can't be blank"
    end

    it "should ensure presence of usage type" do
      showback_usage.group = nil
      showback_usage.valid?
      expect(showback_usage.errors.messages[:group]).to include "can't be blank"
    end

    it "should invalidate incorrect usage type" do
      showback_usage.group = "AA"
      expect(showback_usage).to be_valid
    end

    it "should validate correct usage type" do
      showback_usage.group = "CPU"
      expect(showback_usage).to be_valid
    end

    it "should ensure presence of dimensions included in VALID_TYPES" do
      showback_usage.fields = %w(average number)
      expect(showback_usage).to be_valid
    end

    it 'should return category::group' do
      expect(showback_usage.name).to eq("Vm::CPU")
    end
  end

  context ".seed" do
    let(:expected_showback_usage_type_count) { 28 }

    it "empty table" do
      described_class.seed
      expect(described_class.count).to eq(expected_showback_usage_type_count)
    end

    it "run twice" do
      described_class.seed
      described_class.seed
      expect(described_class.count).to eq(expected_showback_usage_type_count)
    end
  end
end
