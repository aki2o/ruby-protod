# frozen_string_literal: true

RSpec.describe Protod do
  describe ".configure" do
    subject { described_class.configure(&body) }
    let(:body) { ->(c) { receivers.push(c) } }
    let(:receivers) { [] }

    it { expect { subject }.to change { receivers.size }.by(0) }

    context "when configuration called already" do
      before { described_class.configuration }

      it do
        expect { subject }.to change { receivers.size }.by(1)
        expect(receivers.last).to be_a Protod::Configuration
      end

      context "but cleared" do
        before { described_class.clear! }

        it { expect { subject }.to change { receivers.size }.by(0) }
      end
    end
  end

  describe ".configuration" do
    subject { described_class.configuration }

    it { is_expected.to be_a Protod::Configuration }

    context "when configure called" do
      before { described_class.configure { configures.push(:dummy) } }
      let(:configures) { [] }

      it { expect { subject }.to change { configures.size }.by(1) }

      context "but already called" do
        before { described_class.configuration }

        it { expect { subject }.to change { configures.size }.by(0) }
      end
    end

    describe "setup interpreters" do
      before do
        allow(Protod::Interpreter::Builtin).to receive(:setup!) { setups.push(:builtin) }
        allow(Protod::Interpreter::ActiveRecord).to receive(:setup!) { setups.push(:active_record) }
        allow(Protod::Interpreter::Rpc).to receive(:setup!) { setups.push(:rpc) }
      end
      let(:setups) { [] }

      it { expect { subject }.to change { setups.size }.by(3) }

      context "when already called" do
        before { described_class.configuration }

        it { expect { subject }.to change { setups.size }.by(0) }

        context "but cleared" do
          before { described_class.clear! }

          it { expect { subject }.to change { setups.size }.by(3) }
        end
      end
    end
  end

  describe ".clear!" do
    subject { described_class.clear! }

    before do
      described_class.configure do |c|
        c.define_package('com.moneyforward') do
          c.derive_from('Dir') do
            c.define_rpc(:home, singleton: true)
          end
        end
      end

      described_class.setup!
    end

    it do
      expect { subject }.to change { Protod::Proto::Package.roots.size }.to(0)
      .and change { Protod::Rpc::Request.keys.size }.to(0)
      .and change { Protod::Rpc::Response.keys.size }.to(0)
      .and change { Protod::Interpreter.keys.size }.to(0)
    end
  end

  describe ".setup!" do
    subject { described_class.setup! }

    before do
      described_class.configure do |c|
        c.define_package('com.moneyforward') do
          c.derive_from('Dir') do
            c.define_rpc(:home, singleton: true)
          end
        end
      end
    end

    it do
      Protod.configuration.builders.each do |builder|
        expect(builder).to receive(:build).and_call_original
      end

      expect { subject }.to change { Protod::Proto::Package.roots.map(&:built?).uniq }.from([false]).to([true])
      .and change { Protod::Interpreter.reverse_keys&.size }.from(nil).to(be > 0)
    end
  end

  describe ".rbs_method_type_for" do
    subject { described_class.rbs_method_type_for(Protod::RubyIdent.build_from(ruby_ident)) }
    let(:ruby_ident) { 'Dir.home' }

    it { expect(subject).to be_a RBS::MethodType }

    context "with the value given by gem" do
      let(:ruby_ident) { 'Time.current' }

      it { expect { subject }.to raise_error(NotImplementedError) }
    end
  end

  describe ".rbs_definition_for" do
    subject { described_class.rbs_definition_for(const_name, singleton: singleton) }
    let(:const_name) { 'Dir' }
    let(:singleton) { false }

    it do
      expect(subject.methods.key?(:home)).to eq false
      expect(subject.methods.key?(:close)).to eq true
    end

    context "with singleton" do
      let(:singleton) { true }

      it do
        expect(subject.methods.key?(:home)).to eq true
        expect(subject.methods.key?(:close)).to eq false
      end
    end

    context "with unknown name" do
      let(:const_name) { 'Zir' }

      it { expect { subject }.to raise_error(NotImplementedError) }

      context "when rbs defined" do
        around do |example|
          Dir.mktmpdir do |dir|
            dir = Pathname(dir)

            File.write(dir.join('zir.rbs'), zir_rbs)

            Protod.configure do |c|
              c.setup_rbs_environment_loader do |loader|
                loader.add(path: dir)
              end
            end

            example.run
          end
        end
        let(:zir_rbs) { "class Zir < Dir\nend" }

        it do
          expect(subject.methods.key?(:home)).to eq false
          expect(subject.methods.key?(:close)).to eq true
        end
      end
    end
  end
end
