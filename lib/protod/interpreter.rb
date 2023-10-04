# frozen_string_literal: true

class Protod
  class Interpreter
    class << self
      def register_for(*const_names, with: nil, parent: nil, path: nil, force: true, ignore: false, &body)
        base = if with
                 find_by(with)&.class or raise ArgumentError, "Not found the interpreter for #{with}"
               else
                 Base
               end

        Class.new(base, &body).tap do |interpreter_const|
          const_names.each do
            c = Protod::RubyIdent.absolute_of(_1).safe_constantize

            raise ArgumentError, "Not found to constantize for #{_1}" unless c

            next if map.key?(c) && ignore

            raise ArgumentError, "Interpreter already regsitered for #{c.name}" if map.key?(c) && !force

            map[c] = { const: interpreter_const, parent: parent, path: path }
          end
        end
      end

      def find_by(const_or_name, with_register_from_ancestor: false)
        const_name  = const_or_name.is_a?(::String) ? Protod::RubyIdent.absolute_of(const_or_name) : nil
        const       = const_or_name.is_a?(::String) ? const_or_name.safe_constantize : const_or_name
        entryables  = const.respond_to?(:ancestors) ? const.ancestors : [const]
        entry_const = entryables.compact.find { map.key?(_1) }
        entry       = entry_const && map.fetch(entry_const)

        return unless entry

        unless entry.is_a?(Base)
          entry = map[entry_const] = entry.fetch(:const).new(entry_const, **entry.except(:const)).tap do
            _1.extend SkipNilAbility
            _1.extend ProtoMessageCacheable
          end
        end

        return entry unless with_register_from_ancestor

        unless map[const].is_a?(Base)
          map[const] = entry.class.new(const, parent: entry.parent, path: entry.path).tap do
            _1.extend SkipNilAbility
            _1.extend ProtoMessageCacheable
          end
        end

        map.fetch(const)
      end

      def find_by_proto(full_ident)
        raise NotImplementedError, "You need to call Protod::Interpreter.setup_reverse_lookup! before" unless @reverse_map

        @reverse_map[full_ident]
      end

      def keys
        map.keys
      end

      def reverse_keys
        @reverse_map&.keys
      end

      def clear!
        @map = nil
        @reverse_map = nil
      end

      def setup_reverse_lookup!
        @reverse_map = keys.map { find_by(_1) }.uniq.map { [_1.proto_full_ident, _1] }.to_h
      end

      private

      def map
        @map ||= {}
      end
    end

    module SkipNilAbility
      def to_pb_from(rb)
        return if rb.nil?
        super
      end

      def to_rb_from(pb)
        return if pb.nil?
        super
      end
    end

    module ProtoMessageCacheable
      def proto_message
        if @_proto_message.nil?
          @_proto_message = super&.tap do |m|
            next if const.ancestors.any? { _1.in?([Protod::Rpc::Request::Base, Protod::Rpc::Response::Base]) }

            m.fields.unshift(Protod::Proto::Field.build_from('::String', ident: 'protod__object_id', optional: true))
          end

          @_proto_message = false unless @_proto_message
        end

        @_proto_message ? @_proto_message : nil
      end
    end

    class Base
      attr_reader :const, :parent, :path

      def initialize(const, parent: nil, path: nil)
        @const  = const
        @parent = parent
        @path   = path
      end

      def ==(other)
        const == other.const && parent == other.parent && path == other.path
      end

      def bindable?
        return false unless proto_message
        return false if bound?
        true
      end

      def bound?
        return false unless proto_message

        parent.nil?.!
      end

      def set_parent(v)
        raise ArgumentError, "Can't set parent #{v.full_ident} for #{proto_ident} as #{const.name} : already set #{parent.full_ident}" unless parent.nil?
        @parent = v
      end

      def package
        return parent if parent.is_a?(Protod::Proto::Package)

        parent&.ancestor_as(Protod::Proto::Package)
      end

      def proto_path
        @path || package&.proto_path
      end

      def proto_full_ident
        [parent&.full_ident, proto_ident].compact.join('.').presence
      end

      def proto_ident
        Protod::Proto::Ident.build_from(const.name)
      end

      def proto_message
        nil
      end

      def pb_const
        proto_message&.pb_const ||
          Google::Protobuf::DescriptorPool.generated_pool.lookup(proto_full_ident)&.msgclass
      end

      def to_pb_from(rb)
        raise NotImplementedError, "You need to implement #{__method__} for #{const.name}"
      end

      def to_rb_from(pb)
        raise NotImplementedError, "You need to implement #{__method__} for #{const.name}"
      end
    end
  end
end
