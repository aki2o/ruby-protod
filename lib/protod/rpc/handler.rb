class Protod
  module Rpc
    class Handler
      SERVICE_NAME   = 'Handler'
      PROCEDURE_NAME = 'handle'
      ONEOF_NAME     = 'receiver'

      class << self
        def build_in(package)
          package
            .find_or_push(SERVICE_NAME, by: :ident, into: :services)
            .find_or_push(Protod::Proto::Procedure.new(ident: PROCEDURE_NAME, streaming_request: true, streaming_response: true), by: :ident, into: :procedures)
            .tap do |procedure|
            package
              .find_or_push(procedure.request_ident, by: :ident, into: :messages)
              .find_or_push(Protod::Proto::Oneof.new(ident: ONEOF_NAME), by: :ident, into: :fields)

            package
              .find_or_push(procedure.response_ident, by: :ident, into: :messages)
              .find_or_push(Protod::Proto::Oneof.new(ident: ONEOF_NAME), by: :ident, into: :fields)
          end

          new(package)
        end

        def find_package
          Protod::Proto::Package.roots.flat_map(&:all_packages).find do
            _1.find(SERVICE_NAME, by: :ident, as: :service)
              &.find(Protod::Proto::Procedure.new(ident: PROCEDURE_NAME), by: :ident)
          end
        end

        def find_service_in(package)
          package.find(Protod::Rpc::Handler::SERVICE_NAME, by: :ident, as: :service)
        end
      end

      def initialize(package, logger: ::Logger.new(nil))
        @package = package
        @logger  = logger

        @procedure = @package
                       .find(SERVICE_NAME, by: :ident, as: :service)
                       .find(Protod::Proto::Procedure.new(ident: PROCEDURE_NAME), by: :ident)

        @request_receiver_fields  = request_proto_message.find(ONEOF_NAME, by: :ident, as: :oneof)
        @response_receiver_fields = response_proto_message.find(ONEOF_NAME, by: :ident, as: :oneof)

        @loaded_objects = {}
      end

      def request_proto_message
        @package.find(@procedure.request_ident, by: :ident, as: :message)
      end

      def response_proto_message
        @package.find(@procedure.response_ident, by: :ident, as: :message)
      end

      def register_receiver(request_field, response_field)
        @request_receiver_fields.find_or_push(request_field, by: :ident, into: :fields)
        @response_receiver_fields.find_or_push(response_field, by: :ident, into: :fields)
      end

      def handle(req_pb)
        receiver_name = req_pb.public_send(ONEOF_NAME)

        return unless receiver_name

        req_packet = @request_receiver_fields.find(receiver_name, by: :ident, as: :field).then do |f|
          raise InvalidArgument, "Not found acceptable receiver : #{receiver_name}" unless f

          f.interpreter.to_rb_from(req_pb.public_send(receiver_name))
        end

        receiver = if req_packet.receiver_id
                     @loaded_objects[req_packet.receiver_id.to_s] or raise InvalidArgument, "Invalid object_id in request for #{receiver_name}"
                   else
                     req_packet.receiver
                   end

        raise InvalidArgument, "Not found receiver in request for #{receiver_name}" unless receiver
        raise InvalidArgument, "Not found #{req_packet.procedure} in receiver public methods for #{receiver_name}" unless receiver.respond_to?(req_packet.procedure)

        @logger.debug("protod/handle call #{receiver_name}##{req_packet.procedure} : #{req_packet.args} #{req_packet.kwargs}")
        rb = receiver.public_send(req_packet.procedure, *req_packet.args, **req_packet.kwargs)

        memorize_object_id_of(rb)

        res_pb = @response_receiver_fields.find(receiver_name, by: :ident, as: :field).then do |f|
          f.interpreter.to_pb_from(ResponsePacket.new(procedure: req_packet.procedure, object: rb))
        end

        response_pb_const.new(receiver_name.to_sym => res_pb)
      end

      private

      def response_pb_const
        @response_pb_const ||= @package.find(@procedure.response_ident, by: :ident, as: :message).pb_const
      end

      def memorize_object_id_of(value)
        @loaded_objects[value.object_id.to_s] = value
        value.each { memorize_object_id_of(_1) } if Protod::Proto::Field.should_repeated_with(value.class)
      end

      class InvalidArgument < StandardError; end

      RequestPacket  = Struct.new(:receiver_id, :receiver, :procedure, :args, :kwargs, keyword_init: true)
      ResponsePacket = Struct.new(:procedure, :object, keyword_init: true)
    end
  end
end
