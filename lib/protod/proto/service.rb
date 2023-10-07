# frozen_string_literal: true

class Protod
  module Proto
    class Service < Part
      include Findable

      attribute :procedures, default: -> { [] }

      findable_callback_for(:procedure, key: %i[ident ruby_ident ruby_method_name]) do |key, value|
        @procedure_map ? @procedure_map.fetch(key)[value] : procedures.find { _1.public_send(key) == value }
      end

      def ruby_ident
        ident.const_name
      end

      def pb_const
        return unless parent

        parent.pb_const.const_get(ident).const_get('Service')
      end

      def freeze
        procedures.each { _1.depth = depth + 1 }
        procedures.each.with_index(1) { |p, i| p.index = i }

        @procedure_map = self.class.findable_keys_for(:procedure).index_with { |k| procedures.index_by(&k.to_sym) }

        super
      end

      def to_proto
        procedure_part = procedures.map { _1.to_proto }.join("\n").presence
        procedure_part = "\n#{procedure_part}\n" if procedure_part

        [
          format_proto("service %s {%s", ident, procedure_part),
          format_proto("}")
        ].join
      end
    end
  end
end
