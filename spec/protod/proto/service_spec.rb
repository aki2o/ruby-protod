RSpec.describe Protod::Proto::Service, type: :model do
  it_behaves_like :proto_part_root, parentables: [:proto_package]
  it_behaves_like :proto_part_ancestor_as, parentables: [:proto_package]
  it_behaves_like :proto_part_push, childables: [:proto_procedure]
  it_behaves_like :proto_part_freeze

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
