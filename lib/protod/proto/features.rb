# frozen_string_literal: true

class Protod
  module Proto
    class << self
      # https://github.com/protocolbuffers/protobuf/blob/v3.12.0/docs/field_presence.md
      def omits_field?(pb, name)
        return false unless pb.respond_to?("has_#{name}?")
        return false if pb.public_send("has_#{name}?")
        true
      end
    end

    class Ident < ::String
      class << self
        def build_from(const_name)
          return if const_name.blank?

          new(const_name)
        end
      end

      attr_reader :const_name

      def initialize(const_name)
        @const_name = Protod::RubyIdent.absolute_of(const_name)

        super(const_name.gsub('::', '__').delete_prefix('__'))
      end
    end
  end
end
