# frozen_string_literal: true

class Protod
  module Proto
    class Part
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :parent
      attribute :comment, :string
      attribute :ident
      attribute :depth, :integer, default: 0
      attribute :index, :integer, default: 1

      def ident=(value)
        super(Protod::Proto::Ident.build_from(value.to_s))

        raise ArgumentError, "Invalid grpc ident : #{value}. see https://protobuf.dev/reference/protobuf/proto3-spec/#identifiers" unless ident&.match(/\A[a-zA-Z][a-zA-Z0-9_]*\z/)
      end

      def root
        parent ? parent.root : self
      end

      def ancestor_as(part_const)
        parent.is_a?(part_const) ? parent : parent&.ancestor_as(part_const)
      end

      def to_proto
        raise NotImplementedError, "Not defined #{self.class.name}##{__method__}"
      end

      def freeze
        super.tap do
          (attributes.keys - %w[parent]).each do |attribute_name|
            value = attributes.fetch(attribute_name)

            value.freeze

            value.each(&:freeze) if value.is_a?(::Array)
          end
        end
      end

      alias_method :built?, :frozen?

      private

      def format_proto(fmt, *args)
        format("%s#{fmt}", '  ' * depth, *args)
      end
    end

    module Parentable
      extend ActiveSupport::Concern

      class_methods do
        def findable_callback_for(*part_class_names, key:, &body)
          part_class_names.each do |part_class_name|
            k = "Protod::Proto::#{part_class_name.to_s.classify}"

            self._findable_keys_for ||= {}
            self._findable_body_for ||= {}

            self._findable_keys_for[k] = ::Array.wrap(key).map(&:to_s)
            self._findable_body_for[k] = body
          end
        end

        def findable_keys_for(part_class_name)
          k = "Protod::Proto::#{part_class_name.to_s.classify}"

          _findable_keys_for[k] || []
        end
      end

      included do
        class_attribute :_findable_keys_for
        class_attribute :_findable_body_for
      end

      # Find the part
      #
      # @note The target is not descendants but children. For example, if you do `package.find(...)`, the result can
      #       come from only `package.messages` not including `package.messages.first.messages` 
      def find(part, by:, as: nil)
        by    = by.to_s
        value = case part
                when ::String
                  part
                when ::Symbol
                  part.to_s
                else
                  part.public_send(by)
                end
        part  = as ? "Protod::Proto::#{as.to_s.classify}".safe_constantize&.allocate : part
        keys  = _findable_keys_for.fetch(part.class.name, nil)
        body  = _findable_body_for.fetch(part.class.name, nil)

        raise ArgumentError, "Unsupported as : #{as}" if keys.blank? && as
        raise ArgumentError, "Unsupported part : #{part.class.name}" if keys.blank?
        raise ArgumentError, "Unsupported by : #{by}. #{keys.join(', ')} are available" unless by.in?(keys)
        raise NotImplementedError, "Sorry, this is bug forgetting to implement for #{part.class.name} at #{self.class.name}" unless body

        instance_exec(by, value, &body)
      end

      # @return [Protod::Proto::Part] the given part
      def push(part, into:)
        already_pushed = has?(part, in_the: into)

        raise ArgumentError, "Can't push already present #{part.ident} in #{ident}" if already_pushed
        raise ArgumentError, "Can't push already bound to #{part.parent.ident} in #{ident}" if part.parent

        part.assign_attributes(parent: self)

        public_send(into).push(part) unless already_pushed

        part
      end

      # Checking the part has been already pushed
      def has?(part, in_the:)
        public_send(in_the).any? { _1.ident == part.ident }
      end

      # @note There is posibility to raise error on pushing if not found.
      #       That's because, for example, #has? might return true even if #find returns nil.
      # @see #find, #has?
      def find_or_push(part, into:, by:, as: nil, &body)
        new_part = if part.is_a?(::String)
                     c = if as
                           "Protod::Proto::#{as.to_s.classify}".safe_constantize
                         else
                           "Protod::Proto::#{into.to_s.classify}".constantize
                         end

                     raise ArgumentError, "Unsupported as : #{as}" unless c

                     c.new(by.to_sym => part)
                   else
                     part
                   end

        as = part.is_a?(::String) ? new_part.class.name.split('::').last.underscore : nil

        find(part, by: by, as: as) || push(new_part, into: into).tap { body&.call(_1) }
      end
    end

    module FieldCollectable
      def collect_fields
        collector = ->(part) do
          case part
          when Protod::Proto::Package
            part.messages.flat_map { collector.call(_1) }
          when Protod::Proto::Message
            [
              *part.fields.flat_map { collector.call(_1) },
              *part.messages.flat_map { collector.call(_1) },
            ]
          when Protod::Proto::Oneof
            part.fields.flat_map { collector.call(_1) }
          when Protod::Proto::Field
            [part]
          else
            []
          end
        end

        collector.call(self)
      end
    end

    module FieldNumeringable
      def numbering_fields_with(start_index)
        index = start_index

        fields.each do |f|
          case f
          when Protod::Proto::Field
            next if f.void?

            f.index = index

            index = f.index + 1
          when Protod::Proto::Oneof
            index = f.numbering_fields_with(index)
          else
            raise NotImplementedError, "Sorry, this is bug forgetting to implement for #{f.class.name}"
          end
        end

        index
      end
    end

    module InterpreterBindable
      def bind(interpreter)
        raise ArgumentError, "Not bindable interpreter #{interpreter.proto_full_ident} trying bound to #{ident}" unless interpreter.bindable?
        interpreter.set_parent(self)
        interpreter.proto_message.tap do
          push(_1, into: :messages) unless has?(_1, in_the: :messages)
        end
      end
    end
  end
end
