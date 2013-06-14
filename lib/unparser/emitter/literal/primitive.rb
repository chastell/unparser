module Unparser
  class Emitter
    class Literal

      # Base class for primitive emitters
      class Primitive < self

        children :value

      private

        # Dispatch node
        #
        # @return [undefined]
        #
        # @api private
        #
        def dispatch
          if node.location
            emit_source_map
          else
            dispatch_value
          end
        end

        abstract_method :disaptch_value

        # Emitter for primitives based on Object#inspect
        class Inspect < self

          handle :int, :str, :float, :sym

        private

          # Dispatch value
          #
          # @return [undefined]
          #
          # @api private
          #
          def dispatch_value
            buffer.append(value.inspect)
          end

        end # Inspect
      end # Primitive
    end # Literal
  end # Emitter
end # Unparser
