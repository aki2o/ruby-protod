# frozen_string_literal: true

class Protod
  module Proto
    class Message < Part
      include Parentable
      include FieldCollectable
      include FieldNumeringable
      include InterpreterBindable

      attribute :messages, default: -> { [] }
      attribute :fields, default: -> { [] }

      findable_callback_for(:message, key: [:ident, :ruby_ident]) do |key, value|
        @message_map ? @message_map.fetch(key)[value] : messages.find { _1.public_send(key) == value }
      end

      findable_callback_for(:field, key: :ident) do |key, value|
        if @field_map
          @field_map.fetch(key)[value]
        else
          [
            *fields.filter { _1.is_a?(Protod::Proto::Field) },
            *fields.filter { _1.is_a?(Protod::Proto::Oneof) }.flat_map(&:fields)
          ].find { _1.public_send(key) == value }
        end
      end

      findable_callback_for(:oneof, key: :ident) do |key, value|
        if @oneof_map
          @oneof_map.fetch(key)[value]
        else
          fields.filter { _1.is_a?(Protod::Proto::Oneof) }.find { _1.public_send(key) == value }
        end
      end

      def has?(part, in_the:)
        case in_the
        when :fields
          idents = fields.flat_map do |f|
            case f
            when Protod::Proto::Field
              [f.ident]
            when Protod::Proto::Oneof
              [f.ident, *f.fields.map(&:ident)]
            else
              raise ArgumentError, "Unacceptable field : #{f.ident} of #{f.class.name}"
            end
          end

          part_idents = case part
                        when Protod::Proto::Field
                          [part.ident]
                        when Protod::Proto::Oneof
                          [part.ident, *part.fields.map(&:ident)]
                        else
                          raise ArgumentError, "Unacceptable field : #{part.ident} of #{part.class.name}"
                        end

          (part_idents & idents).present?
        else
          super
        end
      end

      def ruby_ident
        ident.const_name
      end

      def full_ident
        [parent&.full_ident, ident].compact.join('.').presence
      end

      def pb_const
        raise NotImplementedError, "Can't call pb_const for #{ident} : not set parent yet" unless parent

        Google::Protobuf::DescriptorPool.generated_pool.lookup(full_ident).msgclass
      end

      def freeze
        messages.each { _1.depth = depth + 1 }
        fields.each { _1.depth = depth + 1 }

        messages.each.with_index(1) { |m, i| m.index = i }
        numbering_fields_with(1)

        @message_map = self.class.findable_keys_for(:message).index_with { |k| messages.index_by(&k.to_sym) }
        @field_map   = self.class.findable_keys_for(:field).index_with { |k| fields.filter { _1.is_a?(Protod::Proto::Field) }.index_by(&k.to_sym) }
        @oneof_map   = self.class.findable_keys_for(:oneof).index_with { |k| fields.filter { _1.is_a?(Protod::Proto::Oneof) }.index_by(&k.to_sym) }

        super
      end

      def to_proto
        message_part = messages.map { _1.to_proto }.join("\n\n").presence

        field_part = fields.filter_map do |f|
          case f
          when Protod::Proto::Field
            next if f.void?

            f.to_proto
          when Protod::Proto::Oneof
            f.to_proto
          else
            raise NotImplementedError, "Sorry, this is bug forgetting to implement for #{f.class.name}"
          end
        end.join("\n").presence

        body = [message_part, field_part].compact.join("\n\n").presence
        body = "\n#{body}\n" if body

        [
          format_proto("message %s {%s", ident, body),
          format_proto("}")
        ].join
      end
    end
  end
end
