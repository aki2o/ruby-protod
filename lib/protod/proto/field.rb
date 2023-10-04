# frozen_string_literal: true

class Protod
  module Proto
    class Field < Part
      attribute :interpreter
      attribute :as_keyword, :boolean, default: false
      attribute :as_rest, :boolean, default: false
      attribute :required, :boolean, default: true  # whether to be not able to omit in Ruby
      attribute :optional, :boolean, default: false # whether to be optional in proto
      attribute :repeated, :boolean, default: false

      class << self
        def build_from(const_or_name, **attributes)
          i = Protod::Interpreter.find_by(const_or_name, with_register_from_ancestor: true)

          raise NotImplementedError, "Not found the interpreter for #{const_or_name}. You can define a interpreter using Protod::Interpreter.register_for" unless i

          new(interpreter: i, **attributes)
        end

        def build_from_rbs(type, on:, **attributes)
          case type
          when RBS::Types::Optional
            build_from_rbs(type.type, on: on, **attributes.merge(optional: attributes[:repeated] ? false : true))
          when RBS::Types::Union
            real_type = type.types.find { _1.name.kind == :class && Protod.rbs_environment.class_decls.key?(_1.name) }

            raise ArgumentError, "Not found declared class in union type on #{on}" unless real_type

            build_from_rbs(real_type, on: on, **attributes)
          when RBS::Types::Alias
            alias_decl = Protod.rbs_environment.type_alias_decls[type.name]

            raise ArgumentError, "Not found alias declaration of #{type.name.name} on #{on}" unless alias_decl

            build_from_rbs(alias_decl.decl.type, on: on, **attributes)
          when RBS::Types::ClassInstance
            case
            when should_repeated_with(type.name.to_s.safe_constantize)
              build_from_rbs(type.args.first, on: on, **attributes.merge(optional: false, repeated: true))
            when type.args.size > 0
              raise NotImplementedError, "Unsupported rbs type : Record or Tuple on #{on}"
            else
              build_from(type.name.to_s, **attributes)
            end
          when RBS::Types::Bases::Base
            build_from(type.class.name, **attributes)
          else
            binding.pry
            raise NotImplementedError, "Unsupported rbs type : #{type.class.name} on #{on}"
          end
        end

        def should_repeated_with(const)
          const&.ancestors&.include?(::Array)
        end
      end

      def void?
        interpreter ? interpreter.proto_ident.blank? : false
      end

      def to_proto
        raise ArgumentError, "Not set interpreter" unless interpreter

        type_part = if interpreter.package && interpreter.package == ancestor_as(Protod::Proto::Package)
                      interpreter.proto_full_ident.delete_prefix("#{interpreter.package.full_ident}.")
                    else
                      interpreter.proto_full_ident
                    end

        [
          format_proto(''),
          [
            # optional ? 'optional' : nil,
            repeated ? 'repeated' : nil,
            type_part,
            ident,
            '=',
            index
          ].compact.join(' '),
          ';'
        ].join
      end
    end
  end
end
