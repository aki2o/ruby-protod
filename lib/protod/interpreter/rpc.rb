# frozen_string_literal: true

class Protod
  class Interpreter
    class Rpc
      def self.setup!
        Interpreter.register_for('Protod::Rpc::Request::Base', force: false, ignore: true) do
          def proto_ident
            "Request"
          end

          def proto_message
            m = Protod.rbs_method_type_for(const.ruby_ident)

            fields = [
              if const.ruby_ident.singleton
                nil
              else
                Protod::Proto::Field.build_from(const.ruby_ident.const_name, ident: const.ruby_ident.const_name)
              end,
              *m.type.required_positionals.map do |arg|
                raise ArgumentError, "Unsupported non-named argument : #{const.ruby_ident}" unless arg.name

                Protod::Proto::Field.build_from_rbs(arg.type, on: const.ruby_ident, ident: arg.name)
              end,
              *m.type.optional_positionals.map do |arg|
                raise ArgumentError, "Unsupported non-named argument : #{const.ruby_ident}" unless arg.name

                Protod::Proto::Field.build_from_rbs(arg.type, on: const.ruby_ident, ident: arg.name, required: false, optional: true)
              end,
              m.type.rest_positionals&.then do |arg|
                raise ArgumentError, "Unsupported non-named argument : #{const.ruby_ident}" unless arg.name

                Protod::Proto::Field.build_from_rbs(arg.type, on: const.ruby_ident, ident: arg.name, as_rest: true, required: false, repeated: true)
              end,
              *m.type.required_keywords.map do |name, arg|
                Protod::Proto::Field.build_from_rbs(arg.type, on: const.ruby_ident, ident: name, as_keyword: true)
              end,
              *m.type.optional_keywords.map do |name, arg|
                Protod::Proto::Field.build_from_rbs(arg.type, on: const.ruby_ident, ident: name, as_keyword: true, required: false, optional: true)
              end,
              m.type.rest_keywords&.then do |arg|
                # Not supporting for now because it's complicated and I can't understand the specification of ruby and rbs about this completely
                raise ArgumentError, "Unsupported rest keywords argument : #{const.ruby_ident}"

                raise ArgumentError, "Unsupported non-named argument : #{const.ruby_ident}" unless arg.name

                Protod::Proto::Field.build_from_rbs(arg.type, on: const.ruby_ident, ident: arg.name, as_keyword: true, as_rest: true, required: false, optional: true)
              end
            ].compact

            Protod::Proto::Message.new(ident: proto_ident, fields: fields)
          end

          def to_rb_from(pb)
            args = []
            kwargs = {}
            receiver_id = nil

            proto_message.fields.each.with_index do |f, i|
              next if Protod::Proto.omits_field?(pb, f.ident) && f.required.!

              f_pb = pb.public_send(f.ident)

              receiver_id = f_pb.protod__object_id if i == 0 && f_pb.respond_to?(:protod__object_id)

              arg = if f.repeated
                      f_pb&.map { f.interpreter.to_rb_from(_1) }
                    else
                      f.interpreter.to_rb_from(f_pb)
                    end

              if f.as_keyword
                kwargs[f.ident.to_sym] = arg
              elsif f.as_rest
                args = [*args, *arg]
              else
                args.push(arg)
              end
            end

            receiver = if const.ruby_ident.singleton
                         const.ruby_ident.const_name.constantize
                       else
                         args.shift
                       end

            Protod::Rpc::Handler::RequestPacket.new(receiver_id: receiver_id, receiver: receiver, args: args, kwargs: kwargs)
          end
        end

        Interpreter.register_for('Protod::Rpc::Response::Base', force: false, ignore: true) do
          def proto_ident
            "Response"
          end

          def proto_message
            m = Protod.rbs_method_type_for(const.ruby_ident)

            fields = if m.type.return_type
                       [Protod::Proto::Field.build_from_rbs(m.type.return_type, on: const.ruby_ident, ident: 'value')]
                     else
                       []
                     end

            Protod::Proto::Message.new(ident: proto_ident, fields: fields)
          end

          def to_pb_from(rb)
            return unless rb

            f = proto_message.find('value', by: :ident, as: 'Protod::Proto::Field')

            return unless f

            pb_maker = ->(v) do
              f.interpreter.to_pb_from(v).tap do
                _1.protod__object_id = v.object_id.to_s if _1.respond_to?(:protod__object_id)
              end
            end

            pb = f.repeated ? rb.map { pb_maker.call(_1) } : pb_maker.call(rb)

            pb_const.new(value: pb)
          end
        end

        Interpreter.register_for('Protod::Rpc::Request::Receiver::Base', force: false, ignore: true) do
          def proto_ident
            "Request"
          end

          def proto_message
            f = Protod::Proto::Oneof.new(ident: Protod::Rpc::Request::Receiver::ONEOF_NAME)

            [
              *proto_fields,
              *const.ruby_ident.const_name.constantize.ancestors.drop(1).filter_map do |c|
                r = Protod::Rpc::Request.find_by(c.name) if c.name
                Interpreter.find_by(r) if r
              end.flat_map(&:proto_fields)
            ].each { f.find_or_push(_1, by: :ident, into: :fields) }

            Protod::Proto::Message.new(ident: proto_ident, fields: [f])
          end

          def to_rb_from(pb)
            procedure = pb.public_send(Protod::Rpc::Request::Receiver::ONEOF_NAME)

            raise Protod::Rpc::Handler::InvalidArgument, "Not set procedure" unless procedure

            f = proto_message
                  .find(Protod::Rpc::Request::Receiver::ONEOF_NAME, by: :ident, as: 'Protod::Proto::Oneof')
                  .find(procedure, by: :ident, as: 'Protod::Proto::Field')

            raise Protod::Rpc::Handler::InvalidArgument, "Not found acceptable procedure : #{procedure}" unless f

            f.interpreter.to_rb_from(pb.public_send(procedure)).tap { _1.procedure = procedure }
          end

          def proto_fields
            const.procedures.map do |ruby_ident|
              Protod::Proto::Field.build_from(Protod::Rpc::Request.find_by(ruby_ident), ident: ruby_ident.method_name)
            end
          end
        end

        Interpreter.register_for('Protod::Rpc::Response::Receiver::Base', force: false, ignore: true) do
          def proto_ident
            "Response"
          end

          def proto_message
            f = Protod::Proto::Oneof.new(ident: Protod::Rpc::Response::Receiver::ONEOF_NAME)

            [
              *proto_fields,
              *const.ruby_ident.const_name.constantize.ancestors.drop(1).filter_map do |c|
                r = Protod::Rpc::Response.find_by(c.name) if c.name
                Interpreter.find_by(r) if r
              end.flat_map(&:proto_fields)
            ].each { f.find_or_push(_1, by: :ident, into: :fields) }

            Protod::Proto::Message.new(ident: proto_ident, fields: [f])
          end

          def to_pb_from(packet)
            f = proto_message
                  .find(Protod::Rpc::Response::Receiver::ONEOF_NAME, by: :ident, as: 'Protod::Proto::Oneof')
                  .find(packet.procedure, by: :ident, as: 'Protod::Proto::Field')

            pb = f.interpreter.to_pb_from(packet.object)

            pb_const.new(packet.procedure.to_sym => pb)
          end

          def proto_fields
            const.procedures.map do |ruby_ident|
              Protod::Proto::Field.build_from(Protod::Rpc::Response.find_by(ruby_ident), ident: ruby_ident.method_name)
            end
          end
        end
      end
    end
  end
end
