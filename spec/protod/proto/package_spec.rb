RSpec.describe Protod::Proto::Package, type: :model do
  it_behaves_like :proto_part_root, parentables: [:proto_package]
  it_behaves_like :proto_part_ancestor_as, parentables: [:proto_package]
  it_behaves_like :proto_part_push, childables: [:proto_package, :proto_service, :proto_message]
  it_behaves_like :proto_part_freeze

  it_behaves_like :proto_part_field_collectable do
    context "has children" do
      let(:instance) { build(:proto_package, :has_children) }

      let(:expected_field_size) do
        fieldables = instance.messages.flat_map(&:fields)

        [
          *fieldables.filter { _1.is_a?(Protod::Proto::Field) },
          *fieldables.filter { _1.is_a?(Protod::Proto::Oneof) }.flat_map(&:fields)
        ].size
      end

      it_behaves_like :collect_field
    end

    context "has child package has children" do
      before { instance.push(child, into: :packages) }
      let(:child) { build(:proto_package, :has_children) }

      # not collecting from child packages
      let(:expected_field_size) { 0 }

      it_behaves_like :collect_field
    end
  end

  it_behaves_like :proto_part_bind

  describe "#find" do
    subject { instance.find(part, by: by, **options) }
    let(:instance) { build(:proto_package) }
    let(:part) { build("proto_#{child}", parent: parent) }
    let(:parent) { nil }
    let(:options) { {} }

    it_behaves_like :proto_part_find_with_unsupported, children: [:procedure, :field, :oneof]

    [false, true].each do |is_frozen|
      context "on #{is_frozen ? 'frozen' : 'not frozen'}" do
        before { instance.freeze if is_frozen }

        describe "for packages" do
          let(:child) { :package }
          let(:by) { :full_ident }

          it { is_expected.to eq nil }

          context "when has child" do
            let(:instance) { super().tap { _1.push(child_part, into: :packages) } }
            let(:child_part) { build(:proto_package, ident: child_ident) }
            let(:child_ident) { part.ident }

            it { is_expected.to eq nil }

            it_behaves_like :proto_part_find_or_push_when, :not_found_and_already_pushed

            context "with a part has parent" do
              let(:parent) { build(:proto_package, ident: parent_ident) }
              let(:parent_ident) { instance.ident }

              it { is_expected.to eq(child_part).and not_eq(part) }

              context "when the child has different ident" do
                let(:child_ident) { "#{super()}new" }

                it { is_expected.to eq nil }
              end

              context "whiches ident is different" do
                let(:parent_ident) { "#{super()}new" }

                it { is_expected.to eq nil }

                it_behaves_like :proto_part_find_or_push_when, :not_found_and_already_pushed
              end

              context "and the parent given" do
                let(:part) { super().parent }

                it { is_expected.to eq(instance).and not_eq(parent) }
              end

              context "when the child has grand child" do
                let(:child_part) { super().tap { _1.push(grand_child_part, into: :packages) } }
                let(:grand_child_part) { build(:proto_package, ident: grand_child_ident) }
                let(:grand_child_ident) { part.ident }
                let(:child_ident) { build(:proto_package).ident }

                let(:parent) { super().tap { _1.parent = grand_parent } }
                let(:parent_ident) { child_ident }
                let(:grand_parent) { build(:proto_package, ident: instance.ident) }

                it { is_expected.to eq(grand_child_part).and not_eq(part) }

                it_behaves_like :proto_part_find_with_stringified, with_find_or_push_examples: false
                it_behaves_like :proto_part_find_or_push_when, :found

                context "and the part parent whiches ident is different" do
                  let(:parent_ident) { "#{super()}new" }

                  it { is_expected.to eq nil }

                  it_behaves_like :proto_part_find_or_push_when, :not_found
                end
              end
            end
          end
        end

        describe "for services" do
          let(:child) { :service }
          let(:by) { :ident }

          it { is_expected.to eq nil }

          context "when has child" do
            let(:instance) { super().tap { _1.push(child_part, into: :services) } }
            let(:child_part) { build(:proto_service, ident: child_ident) }
            let(:child_ident) { part.ident }

            it { is_expected.to eq(child_part).and not_eq(part) }

            it_behaves_like :proto_part_find_with_stringified, with_find_or_push_examples: is_frozen ? false : true
            it_behaves_like :proto_part_find_or_push_when, :found

            context "has different ident" do
              let(:child_ident) { "#{super()}new" }

              it { is_expected.to eq nil }

              it_behaves_like :proto_part_find_or_push_when, is_frozen ? :not_found_and_frozen : :not_found

              context "with a part has parent" do
                let(:parent) { build(:proto_package) }

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

        describe "for messages" do
          let(:child) { :message }
          let(:by) { :ident }

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
                let(:parent) { build(:proto_package) }

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
      end
    end
  end

  describe ".clear!" do
    subject { described_class.clear! }

    before { described_class.find_or_register_package('foo.bar.baz') }

    it { expect { subject }.to change { described_class.roots.size }.to(0) }
  end

  describe ".roots" do
    subject { described_class.roots }

    it { is_expected.to eq [] }

    context "when registered" do
      before { described_class.find_or_register_package('foo.bar.baz') }

      it do
        expect(subject.size).to eq 1
        expect(subject.first).to be_a(Protod::Proto::Package).and have_attributes(ident: 'foo')
      end

      context "more" do
        before { described_class.find_or_register_package('hoge.fuga') }

        it do
          expect(subject.size).to eq 2
          expect(subject.second).to be_a(Protod::Proto::Package).and have_attributes(ident: 'hoge')
        end

        context "and more but same root" do
          before { described_class.find_or_register_package('hoge.piyo') }

          it do
            expect(subject.size).to eq 2
          end
        end
      end
    end
  end

  describe ".find_or_register_package" do
    subject { described_class.find_or_register_package('foo.bar.baz', **options) }
    let(:options) { {} }

    shared_examples_for :perform_normally do |size: 1|
      it do
        expect { subject }.to change { described_class.roots.flat_map(&:all_packages).size }.by(size)

        v = subject

        expect(v).to be_a Protod::Proto::Package
        expect(v.full_ident).to eq 'foo.bar.baz'
        expect(v.parent.ident).to eq 'bar'
        expect(v.parent.parent.ident).to eq 'foo'
        expect(v.url).to eq options[:url]
        expect(v.branch).to eq options[:branch]
      end
    end

    it_behaves_like :perform_normally, size: 3

    context "with options" do
      let(:options) { super().merge(url: 'https://github.com/googleapis/googleapis.git', branch: 'preview') }

      it_behaves_like :perform_normally, size: 3
    end

    context "when same parent package already registered" do
      before { described_class.find_or_register_package('foo.bar.piyo') }

      it_behaves_like :perform_normally, size: 1
    end
  end

#   describe "#full_ident" do
#     subject { instance.full_ident }
#     let(:instance) { described_class.new(**{ parent: parent, ident: ident }.compact) }
#     let(:parent) { Protod::Proto::Package.new(ident: parent_ident) if parent_ident }

#     where(:parent_ident, :ident, :expected_value) do
#       [
#         [nil, nil, nil],
#         [nil, 'foo', 'foo'],
#         ['foo', nil, nil],
#         ['foo', 'bar', 'foo.bar'],
#       ]
#     end

#     with_them do
#       it { is_expected.to eq expected_value }
#     end
#   end

#   describe "#all_packages" do
#     subject { instance.all_packages }
#     let(:instance) { described_class.new }

#     it { is_expected.to contain_exactly(instance) }

#     context "having packages" do
#       before { instance.packages.push(c1, c2) }
#       let(:c1) { described_class.new(ident: 'c1') }
#       let(:c2) { described_class.new(ident: 'c2') }

#       it { is_expected.to contain_exactly(instance, c1, c2) }

#       context "has packages" do
#         before do
#           c1.packages.push(g1, g2)
#           c2.packages.push(g3, g4)
#         end
#         let(:g1) { described_class.new(ident: 'g1') }
#         let(:g2) { described_class.new(ident: 'g2') }
#         let(:g3) { described_class.new(ident: 'g3') }
#         let(:g4) { described_class.new(ident: 'g4') }

#         it { is_expected.to contain_exactly(instance, c1, g1, g2, c2, g3, g4) }
#       end
#     end
#   end

#   describe "#empty?" do
#     subject { instance.empty? }
#     let(:instance) { described_class.new }

#     it { is_expected.to eq true }

#     context "having package" do
#       before { instance.packages.push(described_class.new) }

#       it { is_expected.to eq true }
#     end

#     context "having service" do
#       before { instance.services.push(Protod::Proto::Service.new) }

#       it { is_expected.to eq false }
#     end

#     context "having message" do
#       before { instance.messages.push(Protod::Proto::Message.new) }

#       it { is_expected.to eq false }
#     end
#   end

#   describe "#external?" do
#     subject { instance.external? }
#     let(:instance) { described_class.new }

#     it { is_expected.to eq false }

#     context "having url" do
#       before { instance.url = 'https://github.com/googleapis/googleapis.git' }

#       it { is_expected.to eq true }
#     end
#   end

#   describe "#to_proto" do
#     subject { instance.to_proto }
#     let(:instance) { described_class.new(ident: 'foo') }

#     shared_examples_for :make_proto do
#       it { is_expected.to eq expected_value }
#     end
#     let(:expected_value) do
#       <<~EOS
#         syntax = "proto3";

#         package #{expected_package_ident};#{expected_import}
#       EOS
#     end
#     let(:expected_package_ident) { 'foo' }
#     let(:expected_import) { '' }

#     it_behaves_like :make_proto

#     context "with parent" do
#       before { instance.parent = Protod::Proto::Package.new(parent: Protod::Proto::Package.new(ident: 'baz'), ident: 'bar') }

#       let(:expected_package_ident) { 'baz.bar.foo' }

#       it_behaves_like :make_proto
#     end

#     context "with messages" do
#       before { instance.messages.push(m1, m2) }
#       let(:m1) { Protod::Proto::Message.new(parent: instance, ident: '::Hoge::Fuga') }
#       let(:m2) { Protod::Proto::Message.new(parent: instance, ident: 'Bar__Baz') }

#       let(:expected_value) do
#         <<~EOS
#           #{super()}
#           message Hoge__Fuga {#{expected_message_body}}

#           message Bar__Baz {}
#         EOS
#       end
#       let(:expected_message_body) { '' }

#       it_behaves_like :make_proto

#       context "has fields" do
#         include_context :setup_builtin_interpreters

#         before do
#           interpreter_setup.call

#           m1.fields.push(
#             Protod::Proto::Field.build_from(t1, parent: m1, ident: 'f1'),
#             Protod::Proto::Field.build_from(t2, parent: m1, ident: 'f2')
#           )
#         end
#         let(:interpreter_setup) { -> {} }
#         let(:t1) { 'Integer' }
#         let(:t2) { 'String' }

#         let(:expected_message_body) do
#           <<EOS

#   int64 f1 = 1;
#   string f2 = 2;
# EOS
#         end

#         it_behaves_like :make_proto

#         context "includes void" do
#           let(:t1) { %w[RBS::Types::Bases::Void RBS::Types::Bases::Nil].sample }

#           let(:expected_message_body) do
#             <<EOS

#   string f2 = 1;
# EOS
#           end

#           it_behaves_like :make_proto
#         end

#         context "has package" do
#           let(:interpreter_setup) do
#             -> do
#               stub_const('::Hoge::Piyo', Class.new)

#               described_class.find_or_register_package('abc.xyz').tap do
#                 Protod::Interpreter.register_for('Hoge::Piyo', parent: _1, path: proto_path)
#               end
#             end
#           end
#           let(:proto_path) { nil }

#           let(:t1) { '::Date' }
#           let(:t2) { '::Hoge::Piyo' }

#           let(:expected_message_body) do
#             <<EOS

#   google.type.Date f1 = 1;
#   abc.xyz.Hoge__Piyo f2 = 2;
# EOS
#           end

#           let(:expected_import) do
#             <<~EOS.chomp


#               import "abc/xyz.proto";
#               import "google/type/date.proto";
#             EOS
#           end

#           it_behaves_like :make_proto

#           context "with path" do
#             let(:proto_path) { 'hoge/piyo.proto' }

#             let(:expected_import) do
#               <<~EOS.chomp


#                 import "google/type/date.proto";
#                 import "hoge/piyo.proto";
#               EOS
#             end

#             it_behaves_like :make_proto

#             context "is same path" do
#               let(:proto_path) { 'google/type/date.proto' }

#               let(:expected_import) do
#                 <<~EOS.chomp


#                   import "google/type/date.proto";
#                 EOS
#               end

#               it_behaves_like :make_proto
#             end
#           end
#         end
#       end

#       context "and services" do
#         before { instance.services.push(s1, s2) }
#         let(:s1) { Protod::Proto::Service.new(parent: instance, ident: '::S1::S2') }
#         let(:s2) { Protod::Proto::Service.new(parent: instance, ident: 'S3__S4') }

#         let(:expected_value) do
#           <<~EOS
#             #{super()}
#             service S1__S2 {#{expected_service_body}}

#             service S3__S4 {}
#           EOS
#         end
#         let(:expected_service_body) { '' }

#         it_behaves_like :make_proto

#         context "has procedures" do
#           before { s1.procedures.push(p1, p2) }
#           let(:p1) { Protod::Proto::Procedure.new(parent: s1, ident: 'hello_world', has_request: has_request, has_response: false) }
#           let(:p2) { Protod::Proto::Procedure.new(parent: s1, ident: 'rest_in_peace', has_request: false, has_response: has_response) }
#           let(:has_request) { false }
#           let(:has_response) { false }

#           let(:expected_service_body) do
#             <<EOS

#   rpc HelloWorld (#{expected_request_ident}) returns ();
#   rpc RestInPeace () returns (#{expected_response_ident});
# EOS
#           end
#           let(:expected_request_ident) { '' }
#           let(:expected_response_ident) { '' }

#           it_behaves_like :make_proto

#           context "has request, response" do
#             let(:has_request) { true }
#             let(:has_response) { true }

#             let(:expected_request_ident) { 'S1__S2__HelloWorldRequest' }
#             let(:expected_response_ident) { 'S1__S2__RestInPeaceResponse' }

#             it_behaves_like :make_proto
#           end
#         end
#       end
#     end
#   end
end
