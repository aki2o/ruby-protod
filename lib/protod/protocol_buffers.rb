Protod.setup!

pb_dir = File.absolute_path(Protod.configuration.pb_root_dir)

$LOAD_PATH.unshift(pb_dir) unless $LOAD_PATH.include?(pb_dir)

Protod::Proto::Package.roots.flat_map(&:all_packages)
  .reject(&:external?)
  .reject { _1.services.blank? }
  .each do |package|
  dirs = package.full_ident.split('.')
  file = dirs.pop

  require Pathname.new(pb_dir).join(*dirs, "#{file}_services_pb")
end

require 'google/protobuf/well_known_types'

class Protod
  module ProtocolBuffers
    module GoogleProtobufStructStringified
      def from_hash(hash)
        super(hash.stringify_keys)
      end
    end

    module GoogleProtobufValueStringified
      def from_ruby(value)
        case value
        when ::Symbol
          self.string_value = value.to_s
        else
          super(value)
        end
      end
    end
  end
end

class Google::Protobuf::Struct
  class << self
    prepend Protod::ProtocolBuffers::GoogleProtobufStructStringified
  end
end

Google::Protobuf::Value.prepend Protod::ProtocolBuffers::GoogleProtobufValueStringified
