# frozen_string_literal: true

class Protod
  module Proto
    class Builder
      def initialize(root_package)
        @root_package = root_package
        @receivers    = {}
      end

      def push_receiver(ruby_ident)
        @receivers[ruby_ident.to_s] = true
      end

      def receiver_pushed?(ruby_ident)
        @receivers.key?(ruby_ident.to_s)
      end

      def build
        return if @root_package.built?

        handler = Protod::Rpc::Handler.build_in(@root_package)

        @receivers.keys.each do |receiver|
          package = Protod.find_or_register_package("#{@root_package.full_ident}.#{receiver.underscore.gsub('/', '.')}")

          request_field  = Protod::Proto::Field.build_from(Protod::Rpc::Request.find_by(receiver), ident: receiver)
          response_field = Protod::Proto::Field.build_from(Protod::Rpc::Response.find_by(receiver), ident: receiver)

          handler.register_receiver(request_field, response_field)

          request_message  = package.bind(request_field.interpreter)
          response_message = package.bind(response_field.interpreter)

          bindable_interpreters_under(request_message, response_message).each do |i|
            root_message_name = i.const.ruby_ident.singleton ? 'Singleton' : 'Instance'

            package
              .find_or_push(root_message_name, by: :ident, into: :messages)
              .find_or_push(i.const.ruby_ident.method_name, by: :ident, into: :messages)
              .bind(i)
          end
        end

        models_package = Protod.find_or_register_package("#{@root_package.full_ident}.models")

        while (interpreters = bindable_interpreters_under(*@root_package.all_packages)).present?
          interpreters.each { models_package.bind(_1) }
        end

        # For supporting an Array/Hash instance at the fields whiches type is google.protobuf.Any,
        # make the proto definition for Array emerge even if it's not requried.
        any_interpreter = Protod::Interpreter.find_by('RBS::Types::Bases::Any')
        if @root_package.all_packages.flat_map(&:collect_fields).any? { _1.interpreter == any_interpreter }
          i = Protod::Interpreter.find_by('Array')

          models_package.bind(i) if i.bindable?

          models_package.imports.push(Protod::Interpreter.find_by('Hash').proto_path)
        end
      end

      private

      def bindable_interpreters_under(*parts)
        parts.flat_map(&:collect_fields).filter_map(&:interpreter).uniq.select(&:bindable?)
      end
    end
  end
end
