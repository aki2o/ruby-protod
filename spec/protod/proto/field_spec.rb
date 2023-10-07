RSpec.describe Protod::Proto::Field, type: :model do
  it_behaves_like :proto_part_root, parentables: [:proto_message, :proto_oneof]
  it_behaves_like :proto_part_ancestor_as, parentables: [:proto_message, :proto_oneof]
  it_behaves_like :proto_part_freeze

  # describe ".build_from" do
  #   subject { described_class.build_from(type, **attributes) }
  #   let(:type) { 'Integer' }
  #   let(:attributes) { {} }

  #   it { expect { subject }.to raise_error(NotImplementedError) }

  #   shared_examples_for :build_instance do
  #     it do
  #       is_expected.to be_a(described_class)
  #                        .and have_attributes(**attributes.merge(interpreter: Protod::Interpreter.find_by(type)))
  #     end
  #   end

  #   context "after setup interpreters" do
  #     include_context :load_configuration

  #     it_behaves_like :build_instance

  #     context "with attributes" do
  #       let(:attributes) { super().merge(optional: true, repeated: true) }

  #       it_behaves_like :build_instance
  #     end
  #   end
  # end

  # describe "#void?" do
  #   subject { instance.void? }
  #   let(:instance) { described_class.new }

  #   it { is_expected.to eq false }

  #   context "having interpreter" do
  #     let(:instance) { described_class.build_from(type) }
  #     let(:type) { (Protod::Interpreter.all - void_types).sample }
  #     let(:void_types) { %w[::RBS::Types::Bases::Void ::RBS::Types::Bases::Nil] }

  #     include_context :load_configuration

  #     it { is_expected.to eq false }

  #     context "that's void" do
  #       let(:type) { void_types.sample }

  #       it { is_expected.to eq true }
  #     end
  #   end
  # end

  # describe "#to_proto" do
  #   subject { instance.to_proto }
  #   let(:instance) { described_class.new(**attributes) }
  #   let(:attributes) { { ident: 'f1' } }

  #   it { expect { subject }.to raise_error(ArgumentError) }

  #   context "having interpreter" do
  #     let(:attributes) { super().merge(interpreter: Protod::Interpreter.find_by(type)) }
  #     let(:type) { 'Integer' }

  #     include_context :load_configuration

  #     it { is_expected.to eq "int64 f1;" }

  #     context "and other" do
  #       let(:attributes) { super().merge(optional: optional, repeated: repeated) }

  #       where(:type, :optional, :repeated, :expected_value) do
  #         [
  #           ['Integer', true, false, "optional int64 f1;"],
  #           ['Integer', false, true, "repeated int64 f1;"],
  #           ['Integer', true,  true, "optional repeated int64 f1;"],
  #           ['Date',    true,  true, "optional repeated google.type.Date f1;"],
  #         ]
  #       end

  #       with_them do
  #         it { is_expected.to eq expected_value }
  #       end
  #     end
  #   end
  # end
end
