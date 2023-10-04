# frozen_string_literal: true

RSpec.describe Protod::Configuration do
  describe "#setup_rbs_environment_loader" do
    subject { instance.setup_rbs_environment_loader(&body) }
    let(:instance) { described_class.new }
    let(:body) { nil }

    around do |example|
      Dir.mktmpdir do |dir|
        @dir = Pathname(dir)
        File.write(@dir.join('1.rbs'), rbs)
        example.run
      end
    end
    let(:rbs) { "class HogeFuga\nend" }

    shared_examples_for :successful do |found: nil, not_found: nil|
      it do
        expect { subject }.to not_raise_error

        type_name = RBS::TypeName.new(name: found || not_found, namespace: RBS::Namespace.root)

        expect(instance.rbs_environment.class_decls.key?(type_name)).to eq(found ? true : false)
      end
    end

    it_behaves_like :successful, not_found: :HogeFuga

    context "with body" do
      let(:body) do
        ->(loader) { loader.add(path: @dir) }
      end

      it_behaves_like :successful, found: :HogeFuga
    end
  end

  describe "#define_package" do
    subject { instance.define_package('foo.bar.baz', **options, &body) }
    let(:instance) { described_class.new }
    let(:options) { {} }
    let(:body) { -> {} }

    it do
      expect { subject }.to change { Protod::Proto::Package.roots.flat_map(&:all_packages).map(&:full_ident) }
                              .from([])
                              .to(["foo", "foo.bar", "foo.bar.baz"])
    end

    context "with options" do
      let(:options) { super().merge(for_java: 'com.example.baz') }

      it do
        subject

        expect(Protod.find_or_register_package('foo.bar.baz')).to have_attributes(for_java: 'com.example.baz')
      end
    end
  end

  describe "#derive_from" do
    subject { instance.derive_from(const_name, **options, &body) }
    let(:instance) { described_class.new }
    let(:const_name) { 'Dir' }
    let(:options) { {} }
    let(:body) { -> {} }

    it { expect { subject }.to raise_error(NotImplementedError) }

    context "with define_package" do
      around do |example|
        instance.define_package(package_ident) { example.run }
      end
      let(:package_ident) { 'foo.bar.baz' }

      shared_examples_for :setup_derived do |with_builder: true, as_receiver: true|
        it do
          receiver_expectation = if as_receiver
                                   change { instance.builders.last&.receiver_pushed?(const_name) || false }.from(false).to(true)
                                 else
                                   not_change { instance.builders.last&.receiver_pushed?(const_name) || false }.from(false)
                                 end

          expect { subject }.to change { Protod::Rpc::Request.find_by(const_name) }.from(nil).to(be_present)
                                  .and change { Protod::Rpc::Response.find_by(const_name) }.from(nil).to(be_present)
                                         .and change { instance.builders.size }.by(with_builder ? 1 : 0)
                                                .and receiver_expectation
        end
      end

      it_behaves_like :setup_derived, with_builder: true

      context "when called already" do
        before { instance.derive_from('File') { nil } }

        it_behaves_like :setup_derived, with_builder: false
      end

      context "with abstruct" do
        let(:options) { super().merge(abstruct: true) }

        it_behaves_like :setup_derived, with_builder: false, as_receiver: false
      end
    end
  end

  describe "#define_rpc" do
    subject { instance.define_rpc(*names, **options) }
    let(:instance) { described_class.new }
    let(:names) { [:close] }
    let(:options) { {} }

    it { expect { subject }.to raise_error(NotImplementedError) }

    context "with define_package" do
      around do |example|
        instance.define_package(package_ident) { example.run }
      end
      let(:package_ident) { 'foo.bar.baz' }

      it { expect { subject }.to raise_error(NotImplementedError) }

      context "and derive_from" do
        around do |example|
          instance.derive_from(const_name.to_sym) { example.run }
        end
        let(:const_name) { 'File' }

        shared_examples_for :perform_normally do |as_const: '', as_singleton: false|
          it do
            package = Protod.find_or_register_package('foo.bar.baz')

            expectations = names.flat_map do |name|
              [
                change { Protod::Rpc::Request.find_by(as_const).procedure_pushed?(name, singleton: as_singleton) }.from(false).to(true),
                change { Protod::Rpc::Response.find_by(as_const).procedure_pushed?(name, singleton: as_singleton) }.from(false).to(true)
              ]
            end

            expect { subject }.to expectations.inject(:and)
          end
        end

        it_behaves_like :perform_normally, as_const: 'File'

        context "and more name" do
          let(:names) { [:closed?, *super()] }

          it_behaves_like :perform_normally, as_const: 'File'
        end

        context "and options" do
          let(:options) { super().merge(singleton: true) }
          let(:names) { [:open] }

          it_behaves_like :perform_normally, as_const: 'File', as_singleton: true
        end

        context "and more derive_from" do
          around do |example|
            instance.derive_from('Stat') { example.run }
          end
          let(:names) { [:mode] }

          it_behaves_like :perform_normally, as_const: 'File::Stat'
        end
      end
    end
  end

  describe "#register_interpreter_for" do
    subject { instance.register_interpreter_for(*const_names, **options, &body) }
    let(:instance) { described_class.new }
    let(:const_names) { ['Integer'] }
    let(:options) { {} }
    let(:body) { nil }

    it { expect { subject }.to raise_error(NotImplementedError) }

    context "with define_package" do
      around do |example|
        instance.define_package(package_ident) { example.run }
      end
      let(:package_ident) { 'foo.bar.baz' }

      shared_examples_for :perform_normally do |size: 1|
        it do
          expect { subject }.to change { Protod::Interpreter.keys.size }.by(size)

          const_names.each.with_index do |const_name, index|
            i = Protod::Interpreter.find_by(const_name)

            expect(i).to be_a(Protod::Interpreter::Base)
            expect(i).to be_a(Protod::Interpreter.find_by(options[:with]).class) if options[:with]
            expect(i.proto_ident).to eq expected_proto_idents[index]
          end
        end
      end
      let(:expected_proto_idents) { const_names.map { Protod::Proto::Ident.build_from(_1) } }

      it_behaves_like :perform_normally

      context "and more const_name" do
        let(:const_names) { super().push('String') }

        it_behaves_like :perform_normally, size: 2
      end

      context "and base" do
        let(:options) { super().merge(with: 'Numeric') }

        before { Protod::Interpreter.register_for('Numeric') }

        it_behaves_like :perform_normally
      end

      context "and body" do
        let(:body) do
          ->(_) { def proto_ident = 'int64' }
        end

        let(:expected_proto_idents) { const_names.map { 'int64' } }

        it_behaves_like :perform_normally

        context "when already registered" do
          before { Protod::Interpreter.register_for(*const_names) }

          it_behaves_like :perform_normally, size: 0

          context "not by force" do
            let(:options) { super().merge(force: false) }

            it { expect { subject }.to raise_error(ArgumentError) }
          end
        end
      end
    end
  end
end
