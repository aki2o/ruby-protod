# frozen_string_literal: true

RSpec.shared_context :mock_ident do
  let(:mock_ident) { Faker::Food.fruits.gsub(' ', '').gsub("'", '_') }
end

RSpec.shared_examples_for :proto_part do
  describe "#Ident=" do
    subject { instance.ident = value }
    let(:instance) { described_class.new }

    where(:value, :error?) do
      [
        [nil, true],
        ['', true],
        [:hello, false],
        ['Hoge__Fuga', false]
      ]
    end

    with_them do
      it do
        if error?
          expect { subject }.to raise_error(ArgumentError)
        else
          expect { subject }.to_not raise_error
        end
      end
    end
  end

  describe "#root" do
    subject { instance.root }
    let(:instance) { described_class.new }

    it { is_expected.to eq instance }

    context "having parent" do
      before { instance.parent = parent }
      let(:parent) { Protod::Proto::Package.new(ident: 'foo') }

      it { is_expected.to eq parent }

      context "has parent" do
        before { parent.parent = ancestor }
        let(:ancestor) { Protod::Proto::Package.new(ident: 'bar') }

        it { is_expected.to eq ancestor }
      end
    end
  end
end
