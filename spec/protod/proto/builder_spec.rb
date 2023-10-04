RSpec.describe Protod::Proto::Builder do
  describe "#build" do
    subject { instance.build }
    let(:instance) { described_class.new(package) }
    let(:package) { Protod.find_or_register_package(package_full_ident) }
    let(:package_full_ident) { 'foo.bar.baz' }

    around do |example|
      Dir.mktmpdir do |dir|
        dir = Pathname(dir)

        File.write(dir.join('1.rbs'), rbs) if rbs

        Protod.configure do |c|
          c.setup_rbs_environment_loader { _1.add(path: dir) }
        end

        Protod.configuration

        example.run
      end
    end
    let(:rbs) { nil }

    shared_examples_for :successful do
      it do
        expect { subject }.to not_raise_error
          .and change { package.messages.size }.by(expected_service_messages.size)
          .and change { package.packages.find { _1.ident == 'models' }&.messages&.size || 0 }.by(expected_model_messages.size)
          .and change { package.messages.flat_map(&:fields).size }.by(expected_service_messages.flat_map(&:fields).size)
          .and change { package.packages.find { _1.ident == 'models' }&.messages&.flat_map(&:fields)&.size || 0 }.by(expected_model_messages.flat_map(&:fields).size)

        package.messages.each.with_index do |m, i|
          m.fields.each.with_index do |f, ii|
            expect(f).to have_attributes(expected_service_messages[i].fields[ii].attributes)
          end
        end

        (package.packages.find { _1.ident == 'models' }&.messages || []).each.with_index do |m, i|
          m.fields.each.with_index do |f, ii|
            expect(f).to have_attributes(expected_model_messages[i].fields[ii].attributes)
          end
        end
      end
    end
    let(:expected_service_messages) { [] }
    let(:expected_model_messages) { [] }

    shared_examples_for :unsuccessful do |raising: nil|
      it do
        raise_expectation = raising ? raise_error(raising) : not_raise_error

        expect { subject }.to raise_expectation
          .and change { package.messages.size }.by(0)
          .and change { package.packages.find { _1.ident == 'models' }&.messages&.size || 0 }.by(0)
      end
    end

    it_behaves_like :successful

    context "when defined rpc" do
      before do
        Protod.configure do |c|
          c.define_package(package_full_ident) do
            c.derive_from('Kernighan::Brian') do
              c.define_rpc(*rpc_names)
            end
          end
        end
      end
      let(:rpc_names) { [:hello_world] }

      it_behaves_like :unsuccessful, raising: NotImplementedError

      context "and rbs" do
        let(:rbs) do
          <<~EOS
            module Kernighan
              class Brian
                #{rbs_methods.join("\n    ")}
              end
            end
          EOS
        end
        let(:rbs_methods) { [] }

        it_behaves_like :unsuccessful, raising: NotImplementedError

        context "for the method" do
          let(:rbs_methods) { super().push("def hello_world: (#{rbs_method_arg}) #{rbs_method_block}-> #{rbs_method_ret}") }
          let(:rbs_method_arg) { '' }
          let(:rbs_method_block) { '' }
          let(:rbs_method_ret) { 'String' }
          
          it_behaves_like :unsuccessful, raising: NotImplementedError

          context "when setup interpreters" do
            before do
              Protod.configure do |c|
                c.define_package(package_full_ident) do
                  c.register_interpreter_for('Kernighan::Brian') do
                    def new_proto_message
                      Protod::Proto::Message.new(ident: proto_ident)
                    end
                  end
                end
              end
            end

            let(:expected_service_messages) do
              procedure = package.services.flat_map(&:procedures).find { _1.ruby_ident == '::Kernighan::Brian#hello_world' }

              [
                Protod::Proto::Message.new(parent: package, ident: procedure.request_ident, fields: expected_request_fields),
                Protod::Proto::Message.new(parent: package, ident: procedure.response_ident, fields: expected_response_fields),
              ]
            end
            let(:expected_request_fields) { [Protod::Proto::Field.build_from('Kernighan::Brian', ident: 'self')] }
            let(:expected_response_fields) { [Protod::Proto::Field.build_from('String', ident: 'value')] }
            let(:expected_model_messages) do
              parent = package.packages.find { _1.ident == 'models' }

              [Protod::Proto::Message.new(parent: parent, ident: 'Kernighan::Brian')]
            end

            it_behaves_like :successful

            context "has argument" do
              let(:rbs_method_arg) { 'String s' }

              let(:expected_request_fields) { super().push(Protod::Proto::Field.build_from('String', **expected_field_attributes)) }
              let(:expected_field_attributes) { { ident: 's' } }

              it_behaves_like :successful

              context "non-named" do
                let(:rbs_method_arg) { 'String' }

                it_behaves_like :unsuccessful, raising: ArgumentError
              end

              context "optional" do
                let(:rbs_method_arg) { '?String s' }

                let(:expected_field_attributes) { super().merge(required: false, optional: true) }

                it_behaves_like :successful

                context "non-named" do
                  let(:rbs_method_arg) { '?String' }

                  it_behaves_like :unsuccessful, raising: ArgumentError
                end
              end

              context "nullable" do
                let(:rbs_method_arg) { 'String? s' }

                let(:expected_field_attributes) { super().merge(optional: true) }

                it_behaves_like :successful
              end

              context "array" do
                let(:rbs_method_arg) { 'Array[String] s' }

                let(:expected_field_attributes) { super().merge(repeated: true) }

                it_behaves_like :successful
              end

              context "rest" do
                let(:rbs_method_arg) { '*String s' }

                let(:expected_field_attributes) { super().merge(as_rest: true, required: false, optional: true, repeated: true) }

                it_behaves_like :successful

                context "non-named" do
                  let(:rbs_method_arg) { '*String' }

                  it_behaves_like :unsuccessful, raising: ArgumentError
                end
              end

              context "as keyword" do
                let(:rbs_method_arg) { 's: String' }

                let(:expected_field_attributes) { super().merge(as_keyword: true) }

                it_behaves_like :successful

                context "with name" do
                  let(:rbs_method_arg) { 's: String str' }

                  it_behaves_like :successful
                end

                context "optional" do
                  let(:rbs_method_arg) { '?s: String' }

                  let(:expected_field_attributes) { super().merge(required: false, optional: true) }

                  it_behaves_like :successful
                end

                context "nullable" do
                  let(:rbs_method_arg) { 's: String?' }

                  let(:expected_field_attributes) { super().merge(optional: true) }

                  it_behaves_like :successful
                end

                context "rest" do
                  let(:rbs_method_arg) { '**Hash[Symbol, untyped] s' }

                  it_behaves_like :unsuccessful, raising: ArgumentError

                  context "non-named" do
                    let(:rbs_method_arg) { '**Hash[Symbol, untyped]' }

                    it_behaves_like :unsuccessful, raising: ArgumentError
                  end
                end
              end
            end

            context "has arguments" do
              let(:rbs_method_arg) { 'String a1, *String a2, k1: String?, ?k2: String' }

              let(:expected_request_fields) do
                [
                  *super(),
                  Protod::Proto::Field.build_from('String', ident: 'a1'),
                  Protod::Proto::Field.build_from('String', ident: 'a2', as_rest: true, required: false, optional: true, repeated: true),
                  Protod::Proto::Field.build_from('String', ident: 'k1', as_keyword: true, optional: true),
                  Protod::Proto::Field.build_from('String', ident: 'k2', as_keyword: true, required: false, optional: true),
                ]
              end

              it_behaves_like :successful

              context "includes optional and rest" do
                let(:rbs_method_arg) { 'String a1, ?String a2, *String a3, k1: String, ?k2: String' }

                it_behaves_like :unsuccessful, raising: ArgumentError
              end
            end

            context "has block" do
              let(:rbs_method_block) { '{ () -> void } ' }

              it_behaves_like :unsuccessful, raising: ArgumentError

              context "optional" do
                let(:rbs_method_block) { '?{ () -> void } ' }

                it_behaves_like :successful
              end
            end

            context "multiple" do
              let(:rpc_names) { super().push(:is_scientist) }
              let(:rbs_methods) { super().push('def is_scientist: () -> bool') }

              let(:expected_service_messages) do
                procedure = package.services.flat_map(&:procedures).find { _1.ruby_ident == '::Kernighan::Brian#is_scientist' }

                [
                  *super(),
                  Protod::Proto::Message.new(parent: package, ident: procedure.request_ident, fields: [Protod::Proto::Field.build_from('Kernighan::Brian', ident: 'self')]),
                  Protod::Proto::Message.new(parent: package, ident: procedure.response_ident, fields: [Protod::Proto::Field.build_from('RBS::Types::Bases::Bool', ident: 'value')]),
                ]
              end

              it_behaves_like :successful
            end

            context "and other derives for singleton" do
              before do
                Protod.configure do |c|
                  c.define_package(package_full_ident) do
                    c.register_interpreter_for('Ritchie::Dennis') do
                      def new_proto_message
                        Protod::Proto::Message.new(ident: proto_ident)
                      end
                    end
                    c.derive_from('Ritchie::Dennis') do
                      c.define_rpc(:hello_world, singleton: true)
                    end
                  end
                end
              end

              let(:rbs) do
                <<~EOS
                  #{super()}
                  module Ritchie
                    class Dennis
                      def self.hello_world: () -> void
                    end
                  end
                EOS
              end
              
              let(:expected_service_messages) do
                procedure = package.services.flat_map(&:procedures).find { _1.ruby_ident == '::Ritchie::Dennis.hello_world' }

                [
                  *super(),
                  Protod::Proto::Message.new(parent: package, ident: procedure.response_ident, fields: [Protod::Proto::Field.build_from('RBS::Types::Bases::Void', ident: 'value')]),
                ]
              end

              it_behaves_like :successful
            end
          end
        end
      end
    end
  end
end
