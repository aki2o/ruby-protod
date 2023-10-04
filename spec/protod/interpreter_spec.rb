RSpec.describe Protod::Interpreter do
  describe ".register_for" do
    subject { described_class.register_for(*const_names, **options, &body) }
    let(:const_names) { ['Integer'] }
    let(:options) { {} }
    let(:body) { nil }

    shared_examples_for :successful do |size: 1, base: nil, package: nil, path: nil, proto_ident: nil|
      it do
        expect { subject }.to change { described_class.keys.size }.by(size)

        const_names.each do |const_name|
          i = described_class.find_by(const_name)

          expect(i).to be_a(base ? described_class.find_by(base).class : Protod::Interpreter::Base)
          expect(i.const).to eq const_name.constantize
          expect(i.parent).to eq package ? Protod.find_or_register_package(package) : nil
          expect(i.proto_path).to eq path if path
          expect(i.proto_ident).to eq proto_ident if proto_ident
        end
      end
    end

    shared_examples_for :unsuccessful do
      it do
        expect { subject }.to raise_error(ArgumentError)
                                .and not_change { described_class.keys.size }
      end
    end

    it_behaves_like :successful, size: 1

    context "with not constantize name" do
      let(:const_names) { ['Unknown'] }

      it_behaves_like :unsuccessful
    end

    context "with more const_name" do
      let(:const_names) { super().push('String') }

      it_behaves_like :successful, size: 2

      context "and with" do
        let(:options) { super().merge(with: 'Numeric') }

        it_behaves_like :unsuccessful

        context "when registered" do
          before { described_class.register_for('Numeric') }

          it_behaves_like :successful, size: 2, base: 'Numeric'
        end
      end

      context "and package" do
        let(:options) { super().merge(parent: Protod.find_or_register_package('foo.bar.baz')) }

        it_behaves_like :successful, size: 2, package: 'foo.bar.baz'
      end

      context "and path" do
        let(:options) { super().merge(path: 'hoge/piyo.proto') }

        it_behaves_like :successful, size: 2, path: 'hoge/piyo.proto'
      end

      context "and body" do
        let(:body) do
          ->(_) { def proto_ident = 'HogeFuga' }
        end

        it_behaves_like :successful, size: 2, proto_ident: 'HogeFuga'
      end

      context "when already registered" do
        before { described_class.register_for('Integer') }

        it_behaves_like :successful, size: 1

        context "not by force" do
          let(:options) { super().merge(force: false) }

          it_behaves_like :unsuccessful

          context "and ignore" do
            let(:options) { super().merge(ignore: true) }

            it_behaves_like :successful, size: 1
          end
        end
      end
    end
  end

  describe ".find_by" do
    subject { described_class.find_by(const_or_name, **options) }
    let(:const_or_name) { [const_name, const_name.constantize].sample }
    let(:const_name) { 'Integer' }
    let(:options) { {} }

    it { is_expected.to eq nil }

    context "when registered" do
      before do
        described_class.register_for(registered_name, **registered_options) do
          def proto_message
            Protod::Proto::Message.new(ident: proto_ident)
          end
        end
      end
      let(:registered_name) { const_name }
      let(:registered_options) { {} }

      before { described_class.register_for('String') }

      shared_examples_for :find do |equals_to_registered: true|
        it do
          is_expected.to be_a(Protod::Interpreter::Base).and have_attributes(**expected_attributes)

          registered = described_class.find_by(registered_name)

          if equals_to_registered
            expect(subject.object_id).to eq(registered.object_id)
          else
            expect(subject.object_id).to not_eq(registered.object_id)
          end

          # ensure extending ProtoMessageCacheable that makes the message be cached
          expect(subject.proto_message.object_id).to eq subject.proto_message.object_id
          # ensure extending ProtoMessageCacheable that inserts a field for object_id in the message
          expect(subject.proto_message.fields.first).to have_attributes(
                                                          ident: 'protod__object_id',
                                                          optional: true,
                                                          interpreter: described_class.find_by(::String)
                                                        )

          # ensure extending SkipNilAbility that inhibits to raise error when nil passed
          expect(subject.to_pb_from(nil)).to eq nil
          expect(subject.to_rb_from(nil)).to eq nil
        end
      end
      let(:expected_attributes) { { const: ::Integer } }

      it_behaves_like :find, equals_to_registered: true

      context "and found already" do
        before { described_class.find_by(registered_name) }

        it_behaves_like :find, equals_to_registered: true
      end

      context "ancestor" do
        let(:registered_name) { 'Numeric' }

        let(:expected_attributes) { { const: ::Numeric } }

        it_behaves_like :find, equals_to_registered: true

        context "and found already" do
          before { described_class.find_by(registered_name) }

          it_behaves_like :find, equals_to_registered: true
        end

        context "with_register_from_ancestor" do
          let(:options) { super().merge(with_register_from_ancestor: true) }
          let(:registered_options) { { parent: parent, path: path } }
          let(:parent) { Protod::Proto::Message.new(ident: 'hoge') }
          let(:path) { 'a/b/c.proto' }

          let(:expected_attributes) { { const: ::Integer, parent: parent, path: path } }

          it_behaves_like :find, equals_to_registered: false
        end
      end
    end
  end

  describe ".find_by_proto" do
    subject { described_class.find_by_proto(full_ident) }
    let(:full_ident) { 'google.type.Date' }

    it { expect { subject }.to raise_error(NotImplementedError) }

    context "after setup_reverse_lookup!" do
      before do
        body&.call
        described_class.setup_reverse_lookup!
      end
      let(:body) { nil }

      it { is_expected.to eq nil }

      context "and registered" do
        let(:body) do
          -> do
            described_class.register_for('Date', parent: Protod.find_or_register_package('google.type'))
          end
        end

        it do
          is_expected.to be_a(Protod::Interpreter::Base)
          expect(subject.proto_full_ident).to eq full_ident
        end
      end
    end
  end

  describe ".clear!" do
    subject { described_class.clear! }

    before do
      described_class.register_for('Integer')
      described_class.setup_reverse_lookup!
    end

    it do
      expect { subject }.to change { described_class.keys.size }.to(0)
      .and change { described_class.reverse_keys }.to(nil)
    end
  end
end

RSpec.describe Protod::Interpreter::Base do
  describe "#==" do
    subject { instance.== other }
    let(:instance) { described_class.new(const, parent: parent, path: path) }
    let(:const) { ::Integer }
    let(:parent) { [nil, Protod.find_or_register_package('foo.bar.baz')].sample }
    let(:path) { [nil, 'hoge/piyo.proto'].sample }
    let(:other) { described_class.new(other_const, parent: other_parent, path: other_path) }
    let(:other_const) { const }
    let(:other_parent) { parent }
    let(:other_path) { path }

    it { is_expected.to eq true }

    context "on different const" do
      let(:other_const) { ::Numeric }

      it { is_expected.to eq false }
    end

    context "on different parent" do
      let(:other_parent) { Protod.find_or_register_package('foo.bar') }

      it { is_expected.to eq false }
    end

    context "on different path" do
      let(:other_path) { 'hoge/fuga.proto' }

      it { is_expected.to eq false }
    end
  end

  describe "#bindable?" do
    subject { instance.bindable? }
    let(:instance) { Protod::Interpreter.find_by(const) }
    let(:const) { ::Integer }

    before { Protod::Interpreter.register_for('String') }

    before { Protod::Interpreter.register_for(const.name, parent: parent, &body) }
    let(:parent) { nil }
    let(:body) { ->(_) { def proto_message = Protod::Proto::Message.new(ident: proto_ident) } }

    it { is_expected.to eq true }

    context "when parent present" do
      let(:parent) { Protod.find_or_register_package('foo.bar.baz') }

      it { is_expected.to eq false }
    end

    context "when proto_message blank" do
      let(:body) { nil }

      it { is_expected.to eq false }
    end
  end

  describe "#bound?" do
    subject { instance.bound? }
    let(:instance) { Protod::Interpreter.find_by(const) }
    let(:const) { ::Integer }

    before { Protod::Interpreter.register_for('String') }

    before { Protod::Interpreter.register_for(const.name, parent: parent, &body) }
    let(:parent) { nil }
    let(:body) { ->(_) { def proto_message = Protod::Proto::Message.new(ident: proto_ident) } }

    it { is_expected.to eq false }

    context "when parent present" do
      let(:parent) { Protod.find_or_register_package('foo.bar.baz') }

      it { is_expected.to eq true }

      context "but proto_message blank" do
        let(:body) { nil }

        it { is_expected.to eq false }
      end
    end
  end

  describe "#set_parent" do
    subject { instance.set_parent(parent) }
    let(:instance) { described_class.new(::Integer, parent: original_parent) }
    let(:original_parent) { nil }
    let(:parent) { Protod.find_or_register_package('foo.bar') }

    it { expect { subject }.to not_raise_error.and change { instance.parent }.from(nil).to(parent) }

    context "when parent present" do
      let(:original_parent) { Protod.find_or_register_package('foo.bar.baz') }

      it { expect { subject }.to raise_error(ArgumentError).and not_change { instance.parent } }
    end
  end

  describe "#package" do
    subject { instance.package }
    let(:instance) { described_class.new(::Integer, parent: parent) }
    let(:parent) { nil }

    it { is_expected.to eq nil }

    context "when parent present" do
      let(:parent) { package }
      let(:package) { Protod.find_or_register_package('foo.bar') }

      it { is_expected.to eq parent }

      context "that's not package" do
        let(:parent) do
          package
            .find_or_push('hoge', into: :messages, by: :ident)
            .find_or_push('fuga', into: :messages, by: :ident)
        end

        it { is_expected.to eq parent.ancestor_as(Protod::Proto::Package) }
      end
    end
  end

  describe "#proto_path" do
    subject { instance.proto_path }
    let(:instance) { described_class.new(const, parent: parent, path: path) }
    let(:const) { ::Integer }
    let(:parent) { nil }
    let(:path) { nil }

    it { is_expected.to eq nil }

    context "with parent" do
      let(:parent) { Protod.find_or_register_package('foo.bar.baz') }

      it { is_expected.to eq 'foo/bar/baz.proto' }

      context "and path" do
        let(:path) { 'hoge/piyo.proto' }

        it { is_expected.to eq 'hoge/piyo.proto' }
      end
    end
  end

  describe "#proto_full_ident" do
    subject { instance.proto_full_ident }
    let(:instance) { described_class.new(const, parent: parent) }
    let(:const) { ::File::Stat }
    let(:parent) { nil }

    it { is_expected.to eq 'File__Stat' }

    context "with parent" do
      let(:parent) { Protod.find_or_register_package('foo.bar.baz') }

      it { is_expected.to eq 'foo.bar.baz.File__Stat' }
    end
  end

  describe "#proto_ident" do
    subject { instance.proto_ident }
    let(:instance) { described_class.new(const) }
    let(:const) { ::File::Stat }

    it { is_expected.to be_a(Protod::Proto::Ident).and eq('File__Stat') }
  end

  describe "#pb_const" do
    subject { instance.pb_const }
    let(:instance) { Protod::Interpreter.find_by(const) }
    let(:const) { ::Integer }

    before { Protod::Interpreter.register_for('String') }

    before { Protod::Interpreter.register_for(const.name, &body) }
    let(:body) { ->(_) { def proto_message = Protod::Proto::Message.new(ident: proto_ident) } }

    before do
      allow(instance.proto_message).to receive(:pb_const).and_return(:dummy1)

      stub_const('Google::Protobuf::DescriptorPool', Class.new)
      allow(Google::Protobuf::DescriptorPool).to receive(:generated_pool).and_return(mock_pool)
    end
    let(:mock_pool) do
      double('MockedPool').tap do
        allow(_1).to receive(:lookup).with(instance.proto_full_ident).and_return(mock_descriptor)
      end
    end
    let(:mock_descriptor) { double('MockedDescriptor', msgclass: :dummy2) }

    it { is_expected.to eq :dummy1 }

    context "when proto_message blank" do
      let(:body) { nil }

      it { is_expected.to eq :dummy2 }

      context "and failed to lookup" do
        let(:mock_descriptor) { nil }

        it { is_expected.to eq nil }
      end
    end
  end
end
