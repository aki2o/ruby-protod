# frozen_string_literal: true

class Protod
  module Proto
    class Procedure < Part
      attribute :singleton, :boolean, default: false
      attribute :has_request, :boolean, default: true
      attribute :has_response, :boolean, default: true
      attribute :streaming_request, :boolean, default: false
      attribute :streaming_response, :boolean, default: false

      def ident=(value)
        super(value.to_s.camelize)
      end

      def ruby_ident
        raise ArgumentError, "Not set parent" unless parent

        Protod::RubyIdent.new(const_name: parent.ruby_ident, method_name: ruby_method_name, singleton: singleton).to_s
      end

      def ruby_method_name
        ident.underscore
      end

      def request_ident
        "#{ident}Request"
      end

      def response_ident
        "#{ident}Response"
      end

      def to_proto
        request_part  = format("%s%s", streaming_request ? 'stream ' : '', has_request ? request_ident : '')
        response_part = format("%s%s", streaming_response ? 'stream ' : '', has_response ? response_ident : '')

        format_proto("rpc %s (%s) returns (%s);", ident, request_part, response_part)
      end
    end
  end
end
