# frozen_string_literal: true

class Protod
  class Configuration
    attr_accessor :proto_root_dir, :pb_root_dir

    def initialize
      @proto_root_dir = './proto'
      @pb_root_dir    = './lib'
      @builders       = {}
    end

    def setup_rbs_environment_loader(&body)
      @setup_rbs_environment_loader = body
    end

    def define_package(ident, for_ruby: nil, for_java: nil, &body)
      bkup = @current_root_package

      raise NotImplementedError, "Unsupported nested package not yet!" if bkup

      @current_root_package = Protod.find_or_register_package(ident, for_ruby: for_ruby, for_java: for_java)

      body.call
    ensure
      @current_root_package = bkup
    end

    def derive_from(const_name, abstruct: false, &body)
      raise NotImplementedError, "You need to call #define_package before" unless @current_root_package

      bkup = @current_const
      @current_const = bkup ? "#{bkup}::#{const_name.to_s.delete_prefix('::')}" : const_name.to_s.delete_prefix('::')

      Protod::Rpc::Request::Receiver.register_for(@current_const, force: false, ignore: true)
      Protod::Rpc::Response::Receiver.register_for(@current_const, force: false, ignore: true)

      unless abstruct
        builder = @builders[@current_root_package.full_ident] ||= Protod::Proto::Builder.new(@current_root_package)
        builder.push_receiver(@current_const)
      end

      body.call
    ensure
      @current_const = bkup
    end

    def define_rpc(*names, singleton: false)
      raise NotImplementedError, "You need to call #define_package before" unless @current_root_package
      raise NotImplementedError, "You need to call #derive_from before" unless @current_const

      Protod::Rpc::Request.find_by(@current_const).push_procedure(*names, singleton: singleton)
      Protod::Rpc::Response.find_by(@current_const).push_procedure(*names, singleton: singleton)
    end

    def register_interpreter_for(*const_names, with: nil, force: true, &body)
      raise NotImplementedError, "You need to call #define_package before" unless @current_root_package

      Protod::Interpreter.register_for(*const_names, with: with, force: force, &body)
    end

    def builders
      @builders.values
    end

    def rbs_environment
      @rbs_environment ||= RBS::EnvironmentLoader.new().tap do
        @setup_rbs_environment_loader&.call(_1)
      end.then do
        RBS::Environment.from_loader(_1).resolve_type_names
      end
    end

    def rbs_definition_builder
      @rbs_definition_builder ||= RBS::DefinitionBuilder.new(env: rbs_environment)
    end
  end
end
