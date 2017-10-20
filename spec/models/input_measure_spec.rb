require 'spec_helper'
require 'money-rails/test_helpers'

describe ManageIQ::Consumption::InputMeasure do
  before(:each) do
    ManageIQ::Consumption::InputMeasure.delete_all
  end

  context "validations" do
    let(:showback_input_measure) { FactoryGirl.build(:input_measure) }
    let(:event) { FactoryGirl.build(:showback_data_rollup) }

    it "has a valid factory" do
      expect(showback_input_measure).to be_valid
    end
    it "should ensure presence of category" do
      showback_input_measure.entity = nil
      expect(showback_input_measure).not_to be_valid
    end

    it "should ensure presence of category included in VALID_CATEGORY fail" do
      showback_input_measure.entity = "region"
      expect(showback_input_measure).to be_valid
    end

    it "should ensure presence of description" do
      showback_input_measure.description = nil
      showback_input_measure.valid?
      expect(showback_input_measure.errors[:description]).to include "can't be blank"
    end

    it "should ensure presence of usage type" do
      showback_input_measure.group = nil
      showback_input_measure.valid?
      expect(showback_input_measure.errors.messages[:group]).to include "can't be blank"
    end

    it "should invalidate incorrect usage type" do
      showback_input_measure.group = "AA"
      expect(showback_input_measure).to be_valid
    end

    it "should validate correct usage type" do
      showback_input_measure.group = "CPU"
      expect(showback_input_measure).to be_valid
    end

    it "should ensure presence of dimensions included in VALID_TYPES" do
      showback_input_measure.fields = %w(average number)
      expect(showback_input_measure).to be_valid
    end

    it 'should return category::group' do
      expect(showback_input_measure.name).to eq("Vm::CPU")
    end
  end

  context ".seed" do
    let(:expected_showback_input_measure_count) { 28 }

    it "empty table" do
      described_class.seed
      expect(described_class.count).to eq(expected_showback_input_measure_count)
    end

    it "run twice" do
      described_class.seed
      described_class.seed
      expect(described_class.count).to eq(expected_showback_input_measure_count)
    end
  end
end
