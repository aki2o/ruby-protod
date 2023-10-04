RSpec.shared_examples_for :proto_part_root_feature do |parentables: []|
  subject { instance.root }
  let(:instance) { described_class.new(parent: parent) }
  let(:parent) { nil }

  it { is_expected.to eq instance }

  parentables.each do |parentable|
    context "has parent #{parentable}" do
      let(:parent) { build(parentable, parent: grand_parent) }
      let(:grand_parent) { nil }

      it { is_expected.to eq parent }

      context "has parent" do
        let(:grand_parent) { build(parentable) }

        it { is_expected.to eq grand_parent }
      end
    end
  end
end

RSpec.shared_examples_for :proto_part_ancestor_as_feature do |parentables: []|
  subject { instance.ancestor_as(part_const) }
  let(:instance) { described_class.new(parent: parent) }
  let(:parent) { nil }
  let(:part_const) { part_consts.sample }
  let(:part_consts) { %w[Package Service Procedure Message Field Oneof].map { "Protod::Proto::#{_1}".constantize } }

  it { is_expected.to eq nil }

  parentables.each do |parentable|
    context "has parent #{parentable}" do
      let(:parent) { build(parentable, parent: grand_parent) }
      let(:grand_parent) { nil }

      let(:part_const) { parent.class }

      it { is_expected.to eq parent }

      context "has parent" do
        let(:grand_parent) { build(parentable) }

        it { is_expected.to eq parent }

        context "with other const" do
          let(:part_const) { (part_consts - [parent.class]).sample }

          it { is_expected.to eq nil }
        end

        if parentables.size > 1
          context "of other" do
            let(:grand_parent) { build((parentables - [parentable]).sample) }
            let(:part_const) { grand_parent.class }

            it { is_expected.to eq grand_parent }

            context "with other const" do
              let(:part_const) { (part_consts - [parent.class, grand_parent.class]).sample }

              it { is_expected.to eq nil }
            end
          end
        end
      end
    end
  end
end

RSpec.shared_examples_for :proto_part_push_feature do |childables: []|
  subject { instance.push(part, into: into, **options) }
  let(:instance) { described_class.new }
  let(:options) { {} }

  shared_examples_for :perform do |with_raise: nil, with_push: true, with_bind: true|
    it do
      raise_ex = with_raise ? raise_error(with_raise) : not_raise_error
      size_ex  = with_push ? change { instance.public_send(into).size }.by(1) : not_change { instance.public_send(into).size }
      bind_ex  = with_bind ? change { part.parent }.to(instance) : not_change { part.parent }

      expect { subject }.to [raise_ex, size_ex, bind_ex].inject(:and)
      expect(subject).to eq part unless with_raise
    end
  end

  childables.each do |childable|
    context "for #{childable}" do
      let(:part) { build(childable) }
      let(:into) { childable.to_s.sub('proto_', '').pluralize.to_sym }

      it_behaves_like :perform

      context "when pushed already" do
        before { instance.push(build(childable, ident: part.ident), into: into) }

        it_behaves_like :perform, with_raise: ArgumentError, with_push: false, with_bind: false

        context "with ignore" do
          let(:options) { super().merge(ignore: true) }
         
          it_behaves_like :perform, with_raise: nil, with_push: false, with_bind: true
        end
      end

      context "when bound already" do
        before { described_class.new.push(part, into: into) }

        it_behaves_like :perform, with_raise: ArgumentError, with_push: false, with_bind: false
      end
    end
  end
end

RSpec.shared_examples_for :proto_part_freeze_feature do
  subject { instance.freeze }
  let(:instance) { build("proto_#{described_class.name.split('::').last.underscore}", :has_child) }

  it do
    all_parts_fetcher = ->(i) do
      [
        i,
        *i.attributes.values.filter { _1.is_a?(::Array) }.flat_map do |children|
          children.flat_map { all_parts_fetcher.call(_1) }
        end
      ]
    end

    expect { subject }.to change { all_parts_fetcher.call(instance).map(&:frozen?).uniq }.from([false]).to([true])
  end
end

RSpec.shared_examples_for :proto_part_field_collectable_feature do
  subject { instance.collect_fields }
  let(:instance) { described_class.new }

  it { is_expected.to eq [] }

  shared_examples_for :collect_field do
    it do
      expect(subject.all? { _1.is_a?(Protod::Proto::Field) }).to eq true
      expect(subject.size).to eq expected_field_size
    end
  end
end

RSpec.shared_examples_for :proto_part_bind_feature do
  subject { instance.bind(interpreter) }
  let(:instance) { described_class.new }
  let(:interpreter) { Protod::Interpreter.find_by(const) }
  let(:const) { ::String }

  before { Protod::Interpreter.register_for(const, &body) }
  let(:body) { nil }

  shared_examples_for :unbind do
    it do
      expect { subject }.to raise_error(ArgumentError)
                              .and not_change { interpreter.parent }
                              .and not_change { instance.messages.size }
    end
  end

  shared_examples_for :bind do |with_push: true|
    it do
      expect { subject }.to not_raise_error
                              .and change { interpreter.parent }.to(instance)
                              .and change { instance.messages.size }.by(with_push ? 1 : 0)

      if with_push
        expect(instance.messages.last).to eq interpreter.proto_message
      else
        expect(instance.messages.last).to_not eq interpreter.proto_message
      end

      expect(subject).to eq interpreter.proto_message
    end
  end

  it_behaves_like :unbind

  context "with interpreter has proto_message" do
    let(:body) do
      ->(_) do
        def proto_message
          Protod::Proto::Message.new(ident: proto_ident)
        end
      end
    end

    it_behaves_like :bind, with_push: true

    context "but already bound" do
      before { described_class.new.bind(interpreter) }

      it_behaves_like :unbind
    end

    context "when instance has already proto_message" do
      before { instance.push(Protod::Proto::Message.new(ident: message_ident), into: :messages) }
      let(:message_ident) { interpreter.proto_ident }

      it_behaves_like :bind, with_push: false

      context "has different ident" do
        let(:message_ident) { build(:proto_part).ident }

        it_behaves_like :bind, with_push: true
      end
    end
  end
end
