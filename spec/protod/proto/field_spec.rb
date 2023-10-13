RSpec.describe Protod::Proto::Field, type: :model do
  it_behaves_like :proto_part_root, parentables: [:proto_message, :proto_oneof]
  it_behaves_like :proto_part_ancestor_as, parentables: [:proto_message, :proto_oneof]
  it_behaves_like :proto_part_freeze

  shared_examples_for :build_instance do
    it do
      if expected_const
        expected_full_attributes = {
          as_keyword: false,
          as_rest: false,
          required: true,
          optional: false,
          repeated: false,
          interpreter: Protod::Interpreter.find_by(expected_const)
        }.merge(expected_attributes || {})

        is_expected.to be_a(described_class).and have_attributes(**expected_full_attributes)
      else
        expect { subject }.to raise_error(NotImplementedError)
      end
    end
  end
  let(:expected_attributes) { nil }
  let(:expected_const) { nil }

  describe ".build_from" do
    subject { described_class.build_from(type, **attributes) }
    let(:type) { 'Integer' }
    let(:attributes) { {} }

    it { expect { subject }.to raise_error(NotImplementedError) }

    context "after setup interpreters" do
      include_context :load_configuration

      let(:expected_attributes) { attributes }
      let(:expected_const) { type }

      it_behaves_like :build_instance

      context "with attributes" do
        let(:attributes) { super().merge(optional: true, repeated: true) }

        it_behaves_like :build_instance
      end
    end
  end

  describe ".build_from_rbs" do
    subject { described_class.build_from_rbs(type, on: on, **(attributes || {})) }
    let(:type) { Protod.rbs_method_type_for(Protod::RubyIdent.new(const_name: 'Foo', method_name: 'f1')).type.return_type }
    let(:on) { Faker::String.random }

    include_context :setup_rbs

    let(:rbs) do
      <<~EOS
        class Foo
          def f1: () -> #{type_rbs}
        end
      EOS
    end

    where(:type_rbs, :expected_const, :attributes, :expected_attributes) do
      [
        ['void',                    RBS::Types::Bases::Void, nil, nil],
        ['bool',                    RBS::Types::Bases::Bool, nil, nil],
        ['String',                  ::String,                nil, nil],
        ['Integer',                 ::Integer,               nil, nil],
        ['Integer?',                ::Integer,               nil, { optional: true }],
        ['Integer?',                ::Integer,               { optional: false }, { optional: true }],
        ['Integer?',                ::Integer,               { repeated: true }, { optional: false, repeated: true }],
        ['(String | Integer)',      ::String,                nil, nil],
        ['(Integer | String?)',     ::Integer,               nil, nil],
        ['(String? | Integer)',     ::String,                nil, { optional: true }],
        ['(String? | Integer)',     ::String,                { optional: false }, { optional: true }],
        ['(String? | Integer)',     ::String,                { repeated: true }, { optional: false, repeated: true }],
        ['path',                    ::String,                nil, nil],
        ['[String, Integer]',       nil,                     nil, nil], # Tupple not supported
        ['Array[Integer]',          ::Integer,               nil, { repeated: true }],
        ['Array[Integer]?',         ::Integer,               nil, { repeated: true, optional: false }],
        ['Array[String | Integer]', ::String,                nil, { repeated: true }],
        ['File::Stat',              nil,                     nil, nil],
      ]
    end

    with_them do
      it_behaves_like :build_instance

      context "with attributes" do
        let(:attributes) do
          (super() || {}).merge(as_keyword: true, as_rest: true, required: false)
        end

        let(:expected_attributes) { attributes.merge(super() || {}) }

        it_behaves_like :build_instance
      end
    end
  end

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
