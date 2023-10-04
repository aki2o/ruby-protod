RSpec.describe Protod::Proto::Message, type: :model do
  it_behaves_like :proto_part_root_feature, parentables: [:proto_package, :proto_message]
  it_behaves_like :proto_part_ancestor_as_feature, parentables: [:proto_package, :proto_message]
  it_behaves_like :proto_part_push_feature, childables: [:proto_message, :proto_field]
  it_behaves_like :proto_part_freeze_feature

  # describe "#ident=" do
  #   subject { instance.ident = value }
  #   let(:instance) { described_class.new }
  #   let(:value) { Faker::Number.digit }

  #   before { allow(Protod).to receive(:proto_ident_from).and_return(mock_ident) }

  #   it { expect { subject }.to change { instance.ident }.from(nil).to(mock_ident) }
  # end

  # describe "#ruby_ident" do
  #   subject { instance.ruby_ident }
  #   let(:instance) { described_class.new(ident: ident) }
  #   let(:ident) { Faker::Name.last_name }

  #   before { allow(Protod).to receive(:const_name_from).with(ident).and_return(mock_ident) }

  #   it { is_expected.to eq mock_ident }
  # end
end
