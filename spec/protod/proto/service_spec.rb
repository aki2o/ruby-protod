RSpec.describe Protod::Proto::Service, type: :model do
  it_behaves_like :proto_part_root, parentables: [:proto_package]
  it_behaves_like :proto_part_ancestor_as, parentables: [:proto_package]
  it_behaves_like :proto_part_push, childables: [:proto_procedure]
  it_behaves_like :proto_part_freeze

  describe "#find" do
    subject { instance.find(part, by: by, **options) }
    let(:instance) { build(:proto_service) }
    let(:part) { build(:proto_procedure, parent: parent) }
    let(:parent) { nil }
    let(:by) { :ident }
    let(:options) { {} }

    it_behaves_like :proto_part_find_with_unsupported, children: [:package, :service, :message, :field, :oneof]

    [false, true].each do |is_frozen|
      context "on #{is_frozen ? 'frozen' : 'not frozen'}" do
        before { instance.freeze if is_frozen }

        it { is_expected.to eq nil }

        context "when has child" do
          let(:instance) { super().tap { _1.push(child_part, into: :procedures) } }
          let(:child_part) { build(:proto_procedure, ident: child_ident) }
          let(:child_ident) { part.ident }

          it { is_expected.to eq(child_part).and not_eq(part) }

          it_behaves_like :proto_part_find_with_stringified, with_find_or_push_examples: is_frozen ? false : true
          it_behaves_like :proto_part_find_or_push_when, :found

          context "has different ident" do
            let(:child_ident) { "#{super()}new" }

            it { is_expected.to eq nil }

            it_behaves_like :proto_part_find_or_push_when, is_frozen ? :not_found_and_frozen : :not_found

            context "with a part has parent" do
              let(:parent) { build(:proto_service) }

              it_behaves_like :proto_part_find_or_push_when, is_frozen ? :not_found_and_frozen : :not_found
            end
          end

          context "by ruby_ident" do
            let(:by) { :ruby_ident }
            let(:part) { super().tap { _1.ident = 'hello_world' } }
            let(:child_ident) { 'hello_world' }

            it { expect { subject }.to raise_error(ArgumentError) }

            context "with a part has parent" do
              let(:parent) { build(:proto_service, ident: 'Kernighan::Brian') }
              let(:instance) { super().tap { _1.ident = 'Kernighan::Brian' } }
              let(:child_part) { super().tap { _1.singleton = false } }
              let(:part) { super().tap { _1.singleton = false } }

              it { is_expected.to eq(child_part).and not_eq(part) }

              it_behaves_like :proto_part_find_with_stringified, value: '::Kernighan::Brian#hello_world', with_find_or_push_examples: false

              context "whiches ident is different" do
                let(:parent) { build(:proto_service, ident: 'Kernighan::Dennis') }

                it { is_expected.to eq nil }
              end

              context "but different ident" do
                let(:child_ident) { 'rest_in_peace' }

                it { is_expected.to eq nil }
              end

              context "but singleton" do
                let(:child_part) { super().tap { _1.singleton = true } }

                it { is_expected.to eq nil }
              end
            end
          end

          context "by ruby_method_name" do
            let(:by) { :ruby_method_name }
            let(:part) { super().tap { _1.ident = 'hello_world' } }
            let(:child_ident) { 'hello_world' }

            it { is_expected.to eq(child_part).and not_eq(part) }

            it_behaves_like :proto_part_find_with_stringified, value: 'hello_world', with_find_or_push_examples: false

            context "with a part has different ident" do
              let(:child_ident) { 'rest_in_peace' }

              it { is_expected.to eq nil }
            end
          end
        end
      end
    end
  end

  describe "#ruby_ident" do
    subject { instance.ruby_ident }
    let(:instance) { described_class.new(ident: 'Hoge::Fuga') }

    it { is_expected.to eq '::Hoge::Fuga' }
  end

  describe "#pb_const" do
    subject { instance.pb_const }
    let(:instance) { build(:proto_service, parent: parent) }
    let(:parent) { nil }

    it { is_expected.to eq nil }

    context "having parent" do
      let(:parent) { build(:proto_package) }

      before do
        stub_const(parent.ident, Class.new)
          .const_set(instance.ident, Class.new)
          .const_set('Service', expected_const)
      end
      let(:expected_const) { Class.new }

      it { is_expected.to eq expected_const }
    end
  end
end
