# frozen_string_literal: true

class Protod
  module Proto
    class Package < Part
      include Findable
      include FieldCollectable
      include InterpreterBindable

      attribute :url
      attribute :branch
      attribute :for_ruby, :string
      attribute :for_java, :string
      attribute :packages, default: -> { [] }
      attribute :services, default: -> { [] }
      attribute :messages, default: -> { [] }
      attribute :imports, default: -> { [] }

      findable_callback_for(:package, key: :full_ident) do |key, value|
        @package_map ? @package_map.fetch(key)[value] : all_packages.find { _1.public_send(key) == value }
      end

      findable_callback_for(:service, key: [:ident, :ruby_ident]) do |key, value|
        @service_map ? @service_map.fetch(key)[value] : services.find { _1.public_send(key) == value }
      end

      findable_callback_for(:message, key: [:ident, :ruby_ident]) do |key, value|
        @message_map ? @message_map.fetch(key)[value] : messages.find { _1.public_send(key) == value }
      end

      class << self
        def clear!
          @packages = nil
        end

        def roots
          @packages ||= []
        end

        def find_or_register_package(full_ident, **attributes)
          full_ident.split('.').inject(nil) do |parent, ident|
            current_packages = parent ? parent.packages : roots

            current_packages.find { _1.ident == ident } || new.tap do
              _1.assign_attributes(
                parent: parent,
                ident: ident,
                for_ruby: parent&.for_ruby && "#{parent.for_ruby}::#{ident.camelize}",
                for_java: parent&.for_java && "#{parent.for_java}.#{ident}"
              )

              current_packages.push(_1)
            end
          end.tap do
            _1.assign_attributes(**attributes.compact) if attributes.compact.present?
          end
        end
      end

      def proto_path
        full_ident.gsub('.', '/').then { "#{_1}.proto" }
      end

      def full_ident
        [parent&.full_ident, ident].compact.join('.').presence if ident
      end

      def pb_const
        for_ruby&.constantize || full_ident.split('.').map(&:camelize).join('::').constantize
      end

      def all_packages
        packages.flat_map(&:all_packages).tap { _1.unshift(self) }
      end

      def empty?
        services.empty? && messages.empty?
      end

      def external?
        url.present?
      end

      def freeze
        services.each.with_index(1) { |s, i| s.index = i }
        messages.each.with_index(1) { |m, i| m.index = i }

        @package_map = self.class.findable_keys_for(:package).index_with { |k| all_packages.index_by(&k.to_sym) }
        @service_map = self.class.findable_keys_for(:service).index_with { |k| services.index_by(&k.to_sym) }
        @message_map = self.class.findable_keys_for(:message).index_with { |k| messages.index_by(&k.to_sym) }

        super
      end

      def to_proto
        syntax_part = format_proto("syntax = \"proto3\";")

        package_part = format_proto("package %s;", full_ident)

        option_part = [
          for_ruby ? format_proto("option ruby_package = \"%s\";", for_ruby) : nil,
          for_java ? format_proto("option java_package = \"%s\";", for_java) : nil,
        ].compact.join("\n").presence

        import_part = [
          *collect_fields.filter_map(&:interpreter).uniq.filter_map(&:proto_path).uniq.reject { _1 == proto_path },
          *imports
        ].uniq.sort.map { format_proto('import "%s";', _1) }.join("\n").presence

        message_part = messages.map { _1.to_proto }.join("\n\n").presence
        service_part = services.map { _1.to_proto }.join("\n\n").presence

        [
          [syntax_part, package_part, option_part, import_part, message_part, service_part].compact.join("\n\n"),
          "\n"
        ].join
      end
    end
  end
end
