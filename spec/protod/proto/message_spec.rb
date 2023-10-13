RSpec.describe Protod::Proto::Message, type: :model do
  it_behaves_like :proto_part_root, parentables: [:proto_package, :proto_message]
  it_behaves_like :proto_part_ancestor_as, parentables: [:proto_package, :proto_message]

  it_behaves_like :proto_part_push, childables: [:proto_message, :proto_field, [:proto_oneof, :fields]] do
    context "for proto_oneof has child" do
      let(:part) { build(:proto_oneof) }
      let(:into) { :fields }

      before { instance.push(child, into: into) }
      let(:child) do
        build(:proto_oneof, ident: child_ident).tap do
          _1.push(build(:proto_field, ident: grand_child_ident), into: :fields)
        end
      end
      let(:child_ident) { "#{part.ident}2" }
      let(:grand_child_ident) { part.ident }

      it_behaves_like :perform, with_raise: ArgumentError, with_push: false, with_bind: false

      context "has different ident" do
        let(:grand_child_ident) { "#{part.ident}3" }

        it_behaves_like :perform

        context "with a part has child" do
          let(:part) { super().tap { _1.push(build(:proto_field, ident: part_child_ident), into: :fields) } }
          let(:part_child_ident) { ["#{part.ident}2", "#{part.ident}3"].sample }

          it_behaves_like :perform, with_raise: ArgumentError, with_push: false, with_bind: false

          context "has different ident" do
            let(:part_child_ident) { "#{part.ident}4" }

            it_behaves_like :perform
          end
        end
      end
    end
  end

  it_behaves_like :proto_part_freeze

  it_behaves_like :proto_part_field_collectable do
    let(:expected_field_size) do
      [
        *fieldables.filter { _1.is_a?(Protod::Proto::Field) },
        *fieldables.filter { _1.is_a?(Protod::Proto::Oneof) }.flat_map(&:fields)
      ].size
    end

    context "has children" do
      let(:instance) { build(:proto_message, :has_children) }

      let(:fieldables) { instance.fields }

      it_behaves_like :collect_field
    end

    context "has child package has children" do
      before { instance.push(child, into: :messages) }
      let(:child) { build(:proto_message, :has_children) }

      let(:fieldables) { [*instance.fields, *instance.messages.flat_map(&:fields)] }

      it_behaves_like :collect_field
    end
  end

  it_behaves_like :proto_part_bind

  describe "#find" do
    subject { instance.find(part, by: by, **options) }
    let(:instance) { build(:proto_message) }
    let(:part) { build("proto_#{child}", parent: parent) }
    let(:parent) { nil }
    let(:by) { :ident }
    let(:options) { {} }

    it_behaves_like :proto_part_find_with_unsupported, children: [:package, :service, :procedure]

    [false, true].each do |is_frozen|
      context "on #{is_frozen ? 'frozen' : 'not frozen'}" do
        before { instance.freeze if is_frozen }

        describe "for message" do
          let(:child) { :message }

          it { is_expected.to eq nil }

          context "when has child" do
            let(:instance) { super().tap { _1.push(child_part, into: :messages) } }
            let(:child_part) { build(:proto_message, ident: child_ident) }
            let(:child_ident) { part.ident }

            it { is_expected.to eq(child_part).and not_eq(part) }

            it_behaves_like :proto_part_find_with_stringified, with_find_or_push_examples: is_frozen ? false : true
            it_behaves_like :proto_part_find_or_push_when, :found

            context "has different ident" do
              let(:child_ident) { "#{super()}new" }

              it { is_expected.to eq nil }

              it_behaves_like :proto_part_find_or_push_when, is_frozen ? :not_found_and_frozen : :not_found

              context "with a part has parent" do
                let(:parent) { build([:proto_package, :proto_message].sample) }

                it_behaves_like :proto_part_find_or_push_when, is_frozen ? :not_found_and_frozen : :not_found
              end
            end

            context "by ruby_ident" do
              let(:by) { :ruby_ident }
              let(:part) { super().tap { _1.ident = 'Hoge::Fuga' } }
              let(:child_ident) { 'Hoge::Fuga' }

              it { is_expected.to eq(child_part).and not_eq(part) }

              it_behaves_like :proto_part_find_with_stringified, value: '::Hoge::Fuga', with_find_or_push_examples: false
            end
          end
        end

        describe "for field" do
          let(:child) { :field }

          it { is_expected.to eq nil }

          context "when has child" do
            let(:instance) { super().tap { _1.push(child_part, into: :fields) } }
            let(:child_part) { build(:proto_field, ident: child_ident) }
            let(:child_ident) { part.ident }

            it { is_expected.to eq(child_part).and not_eq(part) }

            it_behaves_like :proto_part_find_with_stringified, with_find_or_push_examples: is_frozen ? false : true
            it_behaves_like :proto_part_find_or_push_when, :found

            context "has different ident" do
              let(:child_ident) { "#{super()}new" }

              it { is_expected.to eq nil }

              it_behaves_like :proto_part_find_or_push_when, is_frozen ? :not_found_and_frozen : :not_found

              context "with a part has parent" do
                let(:parent) { build(:proto_message) }

                it_behaves_like :proto_part_find_or_push_when, is_frozen ? :not_found_and_frozen : :not_found
              end
            end
          end
        end

        describe "for oneof" do
          let(:child) { :oneof }

          it { is_expected.to eq nil }

          context "when has child" do
            let(:instance) { super().tap { _1.push(child_part, into: :fields) } }
            let(:child_part) { build(:proto_oneof, ident: child_ident) }
            let(:child_ident) { part.ident }

            it { is_expected.to eq(child_part).and not_eq(part) }

            it_behaves_like :proto_part_find_with_stringified, with_find_or_push_examples: is_frozen ? false : { into: :fields }
            it_behaves_like :proto_part_find_or_push_when, :found do
              let(:into) { :fields }
            end

            context "has different ident" do
              let(:child_ident) { "#{super()}new" }

              it { is_expected.to eq nil }

              it_behaves_like :proto_part_find_or_push_when, is_frozen ? :not_found_and_frozen : :not_found do
                let(:into) { :fields }
              end

              context "with a part has parent" do
                let(:parent) { build(:proto_message) }

                it_behaves_like :proto_part_find_or_push_when, is_frozen ? :not_found_and_frozen : :not_found do
                  let(:into) { :fields }
                end
              end
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

  describe "#full_ident" do
    subject { instance.full_ident }
    let(:instance) { build(:proto_message, parent: parent) }
    let(:parent) { nil }

    it { is_expected.to eq instance.ident }

    context "having parent" do
      let(:parent) { build([:proto_package, :proto_message].sample, parent: grand_parent) }
      let(:grand_parent) { nil }

      it { is_expected.to eq "#{parent.ident}.#{instance.ident}" }

      context "has parent" do
        let(:grand_parent) { Protod.find_or_register_package('foo.bar.baz') }

        it { is_expected.to eq "foo.bar.baz.#{parent.ident}.#{instance.ident}" }
      end
    end
  end

  describe "#pb_const" do
    subject { instance.pb_const }
    let(:instance) { build(:proto_message, parent: parent) }
    let(:parent) { nil }

    it { expect { subject }.to raise_error(NotImplementedError) }

    context "when parent" do
      let(:parent) { build([:proto_package, :proto_message].sample) }

      before do
        mock_descriptor = double('Google::Protobuf::Descriptor').tap do
          allow(_1).to receive(:msgclass).and_return(expected_const)
        end

        mock_pool = double('Google::Protobuf::DescriptorPool').tap do
          allow(_1).to receive(:lookup).with("#{parent.full_ident}.#{instance.ident}").and_return(mock_descriptor)
        end

        stub_const('Google::Protobuf::DescriptorPool', Class.new).tap do
          allow(_1).to receive(:generated_pool).and_return(mock_pool)
        end
      end
      let(:expected_const) { stub_const(expected_const_name, Class.new) }
      let(:expected_const_name) { "#{parent.full_ident.split('.').map(&:classify).join('::')}::#{instance.ident.classify}" }

      it { is_expected.to eq expected_const }
    end
  end
end
