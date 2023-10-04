# frozen_string_literal: true

require 'rbs'
require 'active_support/all'
require 'active_model'

require_relative "protod/version"
require_relative 'protod/configuration'
require_relative 'protod/ruby_ident'
require_relative 'protod/proto/features'
require_relative 'protod/proto/part'
require_relative 'protod/proto/package'
require_relative 'protod/proto/service'
require_relative 'protod/proto/procedure'
require_relative 'protod/proto/message'
require_relative 'protod/proto/field'
require_relative 'protod/proto/oneof'
require_relative 'protod/proto/builder'
require_relative 'protod/interpreter'
require_relative 'protod/interpreter/builtin'
require_relative 'protod/interpreter/active_record'
require_relative 'protod/interpreter/rpc'
require_relative 'protod/rpc/request'
require_relative 'protod/rpc/response'
require_relative 'protod/rpc/handler'

class Protod
  class << self
    def configure(&body)
      if @configuration
        body.call(@configuration)
      else
        @configures ||= []
        @configures.push(body)
      end
    end

    def configuration
      @configuration ||= Protod::Configuration.new.tap do |c|
        # Interpreters will be needed by Protod::Configuration#register_interpreter_for
        Protod::Interpreter::Builtin.setup!
        Protod::Interpreter::ActiveRecord.setup!
        Protod::Interpreter::Rpc.setup!

        @configures&.each { _1.call(c) }
      end
    end

    def clear!
      @configures = nil
      @configuration = nil
      Protod::Proto::Package.clear!
      Protod::Rpc::Request.clear!
      Protod::Rpc::Response.clear!
      Protod::Interpreter.clear!
    end

    def setup!
      Protod.configuration.builders.each(&:build)
      Protod::Proto::Package.roots.each(&:freeze)
      Protod::Interpreter.setup_reverse_lookup!
    end

    concerning :GlobalUtilities do
      delegate :find_or_register_package, to: Protod::Proto::Package
      delegate :rbs_environment, :rbs_definition_builder, to: :configuration

      def rbs_method_type_for(ruby_ident)
        method_types = rbs_definition_for(ruby_ident.const_name, singleton: ruby_ident.singleton).methods[ruby_ident.method_name.to_sym]&.method_types

        raise NotImplementedError, "Not found rbs for #{ruby_ident}" unless method_types

        m = method_types.find { _1.block.nil? || _1.block.required.! } || method_types.first

        raise ArgumentError, "Unsupported receiving block method : #{ruby_ident}" if m.block&.required

        m
      end

      def rbs_definition_for(const_name, singleton:)
        const_names = const_name.delete_prefix('::').split('::')
        name        = const_names.pop.to_sym
        namespace   = const_names.empty? ? RBS::Namespace.root : RBS::Namespace.new(path: const_names.map(&:to_sym), absolute: true)

        rbs_type_name = RBS::TypeName.new(name: name, namespace: namespace)

        raise NotImplementedError, "Not found rbs for #{const_name}" unless rbs_environment.class_decls.key?(rbs_type_name)

        if singleton
          rbs_definition_builder.build_singleton(rbs_type_name)
        else
          rbs_definition_builder.build_instance(rbs_type_name)
        end
      end
    end
  end

  module Types
    Binary          = Object.new
    UnsignedInteger = Object.new
    Json            = Object.new
  end
end
