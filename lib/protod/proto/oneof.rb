# frozen_string_literal: true

class Protod
  module Proto
    class Oneof < Part
      include Parentable
      include FieldNumeringable

      attribute :fields, default: -> { [] }

      findable_callback_for(:field, :oneof, key: :ident) do |key, value|
        @field_map ? @field_map.fetch(key)[value] : fields.find { _1.public_send(key) == value }
      end

      def freeze
        fields.each { _1.depth = depth + 1 }

        @field_map = self.class.findable_keys_for(:field).index_with { |k| fields.index_by(&k.to_sym) }

        super
      end

      def to_proto
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

        field_part = "\n#{field_part}\n" if field_part

        [
          format_proto("oneof %s {%s", ident, field_part),
          format_proto("}")
        ].join
      end
    end
  end
end
