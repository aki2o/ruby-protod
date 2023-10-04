# frozen_string_literal: true

class Protod
  class Interpreter
    class Builtin
      def self.setup!
        google_protobuf = Protod.find_or_register_package('google.protobuf')
        google_type     = Protod.find_or_register_package('google.type', url: 'https://github.com/googleapis/googleapis.git')

        Interpreter.register_for('RBS::Types::Bases::Any', parent: google_protobuf, path: 'google/protobuf/any.proto', force: false, ignore: true) do
          def proto_ident
            'Any'
          end

          def to_pb_from(rb)
            i = Protod::Interpreter.find_by(rb.class)

            raise NotImplementedError, "Not found the interpreter for #{rb.class.name}. You can define a interpreter using Protod::Interpreter.register_for" unless i

            value = if i.pb_const
                      pb = i.to_pb_from(rb)

                      pb.protod__object_id = rb.object_id.to_s if pb.respond_to?(:protod__object_id)

                      i.pb_const.encode(pb)
                    elsif i.proto_ident
                      pb = i.to_pb_from(rb)

                      case i.proto_ident
                      when 'bool'
                        # ref: https://github.com/ruby-protobuf/protobuf/blob/b866fc5667226d0582f328ab24c648e578c5a380/lib/protobuf/field/bool_field.rb#L46
                        [pb ? 1 : 0].pack('C')
                      when 'double'
                        # ref: https://github.com/ruby-protobuf/protobuf/blob/b866fc5667226d0582f328ab24c648e578c5a380/lib/protobuf/field/double_field.rb#L16
                        [pb].pack('E')
                      when 'sint64', 'sint32'
                        # ref: https://github.com/ruby-protobuf/protobuf/blob/b866fc5667226d0582f328ab24c648e578c5a380/lib/protobuf/field/signed_integer_field.rb#L20-L24
                        if pb >= 0
                          varint_encode(pb << 1)
                        else
                          varint_encode(~(pb << 1))
                        end
                      when 'uint64'
                        # ref: https://github.com/ruby-protobuf/protobuf/blob/b866fc5667226d0582f328ab24c648e578c5a380/lib/protobuf/field/varint_field.rb#L68
                        varint_encode(pb)
                      when 'string', 'bytes'
                        # ref: https://github.com/ruby-protobuf/protobuf/blob/b866fc5667226d0582f328ab24c648e578c5a380/lib/protobuf/field/string_field.rb#L37-L43
                        v = "" + pb
                        if i.proto_ident == 'string' && v.encoding != ::Encoding::UTF_8
                          v.encode!(::Encoding::UTF_8, :invalid => :replace, :undef => :replace, :replace => "")
                        end
                        v.force_encoding(::Encoding::BINARY)
                      else
                        raise NotImplementedError, "Unsupported #{i.proto_ident} on #{__method__} for #{const.name}"
                      end
                    end

            Google::Protobuf::Any.new(type_url: "/#{i.proto_full_ident}", value: value)
          end

          def to_rb_from(pb)
            i = Protod::Interpreter.find_by_proto(pb.type_url.split('/').last)

            raise NotImplementedError, "Not found the interpreter for #{pb.type_url}. You can define a interpreter using Protod::Interpreter.register_for" unless i

            value = if i.pb_const
                      i.pb_const.decode(pb.value)
                    elsif i.proto_ident
                      case i.proto_ident
                      when 'bool'
                        pb.value.unpack('C').first == 1
                      when 'double'
                        pb.value.unpack('E').first
                      when 'sint64', 'sint32'
                        v = varint_decode(StringIO.new(pb.value))

                        (v & 1).zero? ? v >> 1 : ~v >> 1
                      when 'uint64'
                        varint_decode(StringIO.new(pb.value))
                      when 'string', 'bytes'
                        pb.value.dup.force_encoding(i.proto_ident == 'string' ? ::Encoding::UTF_8 : ::Encoding::BINARY)
                      else
                        raise NotImplementedError, "Unsupported #{i.proto_ident} on #{__method__} for #{const.name}"
                      end
                    end

            i.to_rb_from(value)
          end

          private

          # ref: https://github.com/ruby-protobuf/protobuf/blob/b866fc5667226d0582f328ab24c648e578c5a380/lib/protobuf/varint_pure.rb#L10-L29

          def varint_encode(value)
            bytes = []
            until value < 128
              bytes << (0x80 | (value & 0x7f))
              value >>= 7
            end
            (bytes << value).pack('C*')
          end

          def varint_decode(stream)
            value = index = 0
            begin
              byte = stream.readbyte
              value |= (byte & 0x7f) << (7 * index)
              index += 1
            end while (byte & 0x80).nonzero?
            value
          end
        end

        Interpreter.register_for(*%w[RBS::Types::Bases::Void RBS::Types::Bases::Nil], force: false, ignore: true) do
          def proto_ident
            nil
          end

          def to_pb_from(rb)
            nil
          end

          def to_rb_from(pb)
            nil
          end
        end

        Interpreter.register_for('TrueClass', 'FalseClass', 'RBS::Types::Bases::Bool', force: false, ignore: true) do
          def proto_ident
            'bool'
          end

          def to_pb_from(rb)
            rb ? true : false
          end

          def to_rb_from(pb)
            pb
          end
        end

        Interpreter.register_for('Numeric', force: false, ignore: true) do
          def proto_ident
            'double'
          end

          def to_pb_from(rb)
            rb.to_f
          end

          def to_rb_from(pb)
            pb
          end
        end

        Interpreter.register_for('Integer', force: false, ignore: true) do
          def proto_ident
            'sint64'
          end

          def to_pb_from(rb)
            rb.to_i
          end

          def to_rb_from(pb)
            pb
          end
        end

        Interpreter.register_for('Fixnum', force: false, ignore: true) do
          def proto_ident
            'sint32'
          end

          def to_pb_from(rb)
            rb.to_i
          end

          def to_rb_from(pb)
            pb
          end
        end

        Interpreter.register_for('String', force: false, ignore: true) do
          def proto_ident
            'string'
          end

          def to_pb_from(rb)
            rb.to_s
          end

          def to_rb_from(pb)
            pb
          end
        end

        Interpreter.register_for('BigDecimal', parent: google_type, path: 'google/type/decimal.proto', force: false, ignore: true) do
          def proto_ident
            'Decimal'
          end

          def to_pb_from(rb)
            Google::Type::Decimal.new(value: rb.to_s)
          end

          def to_rb_from(pb)
            BigDecimal(pb.value)
          end
        end

        Interpreter.register_for('Date', parent: google_type, path: 'google/type/date.proto', force: false, ignore: true) do
          def proto_ident
            'Date'
          end

          def to_pb_from(rb)
            Google::Type::Date.new(year: rb.year, month: rb.month, day: rb.day)
          end

          def to_rb_from(pb)
            ::Date.new(pb.year, pb.month, pb.day)
          end
        end

        Interpreter.register_for('Time', 'DateTime', 'ActiveSupport::TimeWithZone', parent: google_protobuf, path: 'google/protobuf/timestamp.proto', force: false, ignore: true) do
          def proto_ident
            'Timestamp'
          end

          def to_pb_from(rb)
            Google::Protobuf::Timestamp.new(seconds: rb.to_i, nanos: rb.nsec)
          end

          def to_rb_from(pb)
            ::Time.zone.at(pb.seconds, pb.nanos, :nanosecond)
          end
        end

        Interpreter.register_for('Protod::Types::Binary', force: false, ignore: true) do
          def proto_ident
            'bytes'
          end

          def to_pb_from(rb)
            rb
          end

          def to_rb_from(pb)
            pb
          end
        end

        Interpreter.register_for('Protod::Types::UnsignedInteger', force: false, ignore: true) do
          def proto_ident
            'uint64'
          end

          def to_pb_from(rb)
            rb.to_i
          end

          def to_rb_from(pb)
            pb
          end
        end

        Interpreter.register_for('Array', force: false, ignore: true) do
          def proto_message
            Protod::Proto::Message.new(
              ident: proto_ident,
              fields: [Protod::Proto::Field.build_from('RBS::Types::Bases::Any', ident: 'values', optional: true, repeated: true)]
            )
          end

          def to_pb_from(rb)
            i = Protod::Interpreter.find_by('RBS::Types::Bases::Any')

            pb_const.new(values: rb.map { i.to_pb_from(_1) })
          end

          def to_rb_from(pb)
            i = Protod::Interpreter.find_by('RBS::Types::Bases::Any')

            pb.values.map { i.to_rb_from(_1) }
          end
        end

        Interpreter.register_for('Hash', parent: google_protobuf, path: 'google/protobuf/struct.proto', force: false, ignore: true) do
          def proto_ident
            'Struct'
          end

          def to_pb_from(rb)
            Google::Protobuf::Struct.from_hash(rb)
          end

          def to_rb_from(pb)
            pb.to_h
          end
        end

        Interpreter.register_for(*['Data', 'Struct'].select(&:safe_constantize), force: false, ignore: true) do
          def proto_message
            Protod::Proto::Message.new(
              ident: proto_ident,
              fields: const.memebers.map do |name|
                Protod::Proto::Field.build_from('RBS::Types::Bases::Any', ident: name, optional: true)
              end
            )
          end

          def to_pb_from(rb)
            attributes = const.members.map { [_1, rb.public_send(_1)] }.to_h

            pb_const.new(**attributes)
          end

          def to_rb_from(pb)
            attributes = const.members.map { [_1, pb.public_send(_1)] }.to_h

            const.new(**attributes)
          end
        end
      end
    end
  end
end
