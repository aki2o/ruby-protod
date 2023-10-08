RSpec.describe Protod::Proto::Procedure, type: :model do
  it_behaves_like :proto_part_root, parentables: [:proto_service]
  it_behaves_like :proto_part_ancestor_as, parentables: [:proto_service]
  it_behaves_like :proto_part_freeze

  describe "#ruby_ident" do
    subject { instance.ruby_ident }
    let(:instance) { described_class.new(ident: ident, parent: parent) }
    let(:ident) { Faker::Types.rb_string }
    let(:parent) { nil }

    it { expect { subject }.to raise_error(ArgumentError) }

    context "with parent" do
      let(:parent) { build(:proto_service) }

      it { is_expected.to eq "#{parent.ruby_ident}##{instance.ruby_method_name}" }

      context "as singleton" do
        before { instance.singleton = true }

        it { is_expected.to eq "#{parent.ruby_ident}.#{instance.ruby_method_name}" }
      end
    end
  end

  describe "#ruby_method_name" do
    subject { instance.ruby_method_name }
    let(:instance) { described_class.new(ident: ident) }
    let(:ident) { Faker::Types.rb_string }

    it { is_expected.to eq ident }
  end

  describe "#request_ident" do
    subject { instance.request_ident }
    let(:instance) { described_class.new(ident: ident) }
    let(:ident) { Faker::Types.rb_string }

    it { is_expected.to eq "#{ident.camelize}Request" }
  end

  describe "#response_ident" do
    subject { instance.response_ident }
    let(:instance) { described_class.new(ident: ident) }
    let(:ident) { Faker::Types.rb_string }

    it { is_expected.to eq "#{ident.camelize}Response" }
  end
end
