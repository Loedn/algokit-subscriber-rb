# frozen_string_literal: true

module Algokit
  module Subscriber
    module Types
      class Arc28EventGroup
        attr_accessor :group_name, :events

        def initialize(group_name:, events:)
          @group_name = group_name
          @events = events.map { |e| e.is_a?(Arc28EventDefinition) ? e : Arc28EventDefinition.new(**e) }
        end
      end

      class Arc28EventDefinition
        attr_accessor :name, :signature, :args

        def initialize(name:, signature: nil, args: [])
          @name = name
          @signature = signature || generate_signature(name, args)
          @args = args.map { |a| a.is_a?(Arc28EventArg) ? a : Arc28EventArg.new(**a) }
        end

        def selector
          @selector ||= Digest::SHA2.digest(@signature)[0..3]
        end

        private

        def generate_signature(name, args)
          arg_types = args.map { |a| a.is_a?(Hash) ? a[:type] : a.type }.join(",")
          "#{name}(#{arg_types})"
        end
      end

      class Arc28EventArg
        attr_accessor :name, :type, :struct

        def initialize(name:, type:, struct: nil)
          @name = name
          @type = type
          @struct = struct
        end
      end

      class Arc28Event
        attr_accessor :group_name, :event_name, :event_signature, :args

        def initialize(group_name:, event_name:, event_signature:, args:)
          @group_name = group_name
          @event_name = event_name
          @event_signature = event_signature
          @args = args
        end

        def to_h
          {
            group_name: @group_name,
            event_name: @event_name,
            event_signature: @event_signature,
            args: @args
          }
        end
      end
    end
  end
end
