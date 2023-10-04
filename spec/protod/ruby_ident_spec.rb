RSpec.describe Protod::RubyIdent do
  describe ".build_from" do
    subject { described_class.build_from(string) }
    let(:string) { [nil, ''].sample }

    it { is_expected.to eq nil }

    shared_examples_for :make_with do |const_name: nil, method_name: nil, singleton: false|
      it do
        is_expected.to be_a(described_class)
                         .and have_attributes(const_name: const_name, method_name: method_name, singleton: singleton)
      end
    end

    context "with class string" do
      let(:string) { 'File' }

      it_behaves_like :make_with, const_name: '::File', method_name: nil, singleton: false

      context "nested" do
        where(:string) do
          ['File::Stat', 'File__Stat', '::File::Stat', '__File__Stat'].map { Array.wrap(_1) }
        end

        with_them do
          it_behaves_like :make_with, const_name: '::File::Stat', method_name: nil, singleton: false
        end
      end
    end

    context "with instance method string" do
      let(:string) { 'Dir#close' }

      it_behaves_like :make_with, const_name: '::Dir', method_name: 'close', singleton: false
    end

    context "with singleton method string" do
      let(:string) { 'Dir.home' }

      it_behaves_like :make_with, const_name: '::Dir', method_name: 'home', singleton: true
    end

    context "with unknown method string" do
      let(:string) { 'Zir.home' }

      it { is_expected.to eq nil }
    end
  end

  describe ".absolute_of" do
    subject { described_class.absolute_of(ruby_ident) }

    where(:ruby_ident) do
      ['File::Stat', '::File::Stat', described_class.build_from('File::Stat')].map { Array.wrap(_1) }
    end

    with_them do
      it { is_expected.to eq '::File::Stat' }
    end

    context "with blank value" do
      let(:ruby_ident) { ['', nil].sample }

      it { is_expected.to eq nil }
    end
  end

  describe "#==" do
    subject { instance.== other }
    let(:instance) { described_class.build_from(value) }

    where(:value, :other, :equals?) do
      [
        ['File::Stat#mode', described_class.build_from('File::Stat#mode'), true],
        ['File::Stat#mode', described_class.build_from('::File::Stat#mode'), true],
        ['File::Stat#mode', '::File::Stat#mode', true],
        ['File::Stat#mode', 'File::Stat#mode', false],
      ]
    end

    with_them do
      it { is_expected.to eq equals? }
    end
  end

  describe "#to_s" do
    subject { instance.to_s }
    let(:instance) { described_class.new(const_name: const_name, method_name: method_name, singleton: singleton) }

    where(:const_name, :method_name, :singleton, :expected_value) do
      [
        ['File::Stat', 'mode', false, '::File::Stat#mode'],
        ['File::Stat', 'new', true, '::File::Stat.new'],
        ['File::Stat', nil, [true, false].sample, '::File::Stat'],
      ]
    end

    with_them do
      it { is_expected.to eq expected_value }
    end
  end
end
