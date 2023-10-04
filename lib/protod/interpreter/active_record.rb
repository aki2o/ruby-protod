# frozen_string_literal: true

class Protod
  class Interpreter
    class ActiveRecord
      def self.setup!
        setup_active_model! if defined?(::ActiveModel::Attributes)
        setup_active_record! if defined?(::ActiveRecord::Attributes)
      end

      private

      def self.setup_active_model!
        Interpreter.register_for('ActiveModel::Attributes', force: false, ignore: true) do
          def proto_message
            i = const.new

            Protod::Proto::Message.new(
              ident: proto_ident,
              fields: const.attribute_names.map do |name|
                Protod::Proto::Field.build_from(
                  resolve_type_from(const.attribute_types.fetch(name)) || 'RBS::Types::Bases::Any',
                  ident: name,
                  required: false,
                  optional: true,
                  repeated: i.method(name).call.is_a?(::Array) ? true : false
                )
              end
            )
          end

          def resolve_type_from(attribute_type)
            case attribute_type
            when ::ActiveModel::Type::Boolean
              'RBS::Types::Bases::Bool'
            when ::ActiveModel::Type::String, ::ActiveModel::Type::ImmutableString
              'String'
            when ::ActiveModel::Type::Decimal
              'BigDecimal'
            when ::ActiveModel::Type::Integer, ::ActiveModel::Type::BigInteger
              'Integer'
            when ::ActiveModel::Type::Float
              'Numeric'
            when ::ActiveModel::Type::Date
              'Date'
            when ::ActiveModel::Type::Time, ::ActiveModel::Type::DateTime
              'Time'
            when ::ActiveModel::Type::Binary
              'Protod::Types::Binary'
            end
          end

          def to_pb_from(rb)
            acceptable_names = const.attribute_names.index_with(true)

            attributes = proto_message.fields.filter_map do |f|
              name = f.ident

              next unless acceptable_names.key?(name)

              [
                name.to_sym,
                if f.repeated
                  rb.attributes.fetch(name).map { f.interpreter.to_pb_from(_1) }
                else
                  f.interpreter.to_pb_from(rb.attributes.fetch(name))
                end
              ]
            end.to_h

            pb_const.new(**attributes)
          end

          def to_rb_from(pb)
            acceptable_names = const.attribute_names.index_with(true)

            attributes = proto_message.fields.map do |f|
              name = f.ident

              next unless acceptable_names.key?(name)
              next if Protod::Proto.omits_field?(pb, name)

              [
                name.to_sym,
                if f.repeated
                  pb.public_send(name)&.map { f.interpreter.to_rb_from(_1) }
                else
                  f.interpreter.to_rb_from(pb.public_send(name))
                end
              ]
            end.compact.to_h

            const.new(**attributes)
          end
        end
      end

      def self.setup_active_record!
        Interpreter.register_for('ActiveRecord::Attributes', with: 'ActiveModel::Attributes', force: false, ignore: true) do
          def resolve_type_from(attribute_type)
            case attribute_type
            when ::ActiveRecord::Type::Boolean
              'RBS::Types::Bases::Bool'
            when ::ActiveRecord::Type::String, ::ActiveRecord::Type::ImmutableString, ::ActiveRecord::Type::Text
              'String'
            when ::ActiveRecord::Type::Decimal, ::ActiveRecord::Type::DecimalWithoutScale
              'BigDecimal'
            when ::ActiveRecord::Type::UnsignedInteger
              'Protod::Types::UnsignedInteger'
            when ::ActiveRecord::Type::Integer, ::ActiveRecord::Type::BigInteger
              'Integer'
            when ::ActiveRecord::Type::Float
              'Numeric'
            when ::ActiveRecord::Type::Date
              'Date'
            when ::ActiveRecord::Type::Time, ::ActiveRecord::Type::DateTime
              'Time'
            when ::ActiveRecord::Type::Json
              'Protod::Types::Json'
            when ::ActiveRecord::Type::Binary
              'Protod::Types::Binary'
            else
              case attribute_type.type
              when :boolean
                'RBS::Types::Bases::Bool'
              when :string
                'String'
              when :integer
                'Integer'
              when :datetime
                'Time'
              else
                super
              end
            end
          end
        end

        Interpreter.register_for('ActiveRecord::Relation', force: false, ignore: true) do
          def proto_ident
            Protod::Proto::Ident.build_from('ActiveRecord::Relation')
          end

          def proto_message
            Protod::Proto::Message.new(
              ident: proto_ident
            )
          end

          def to_pb_from(rb)
            pb_const.new
          end

          def to_rb_from(pb)
            pb
          end
        end
      end
    end
  end
end
