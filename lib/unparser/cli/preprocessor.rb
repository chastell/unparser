# encoding: utf-8

module Unparser
  class CLI

    # CLI Specific preprocessor used for equivalency testing
    class Preprocessor
      include Adamantium::Flat, NodeHelpers, AbstractType, Concord.new(:node), Procto.call(:result)

      # Return preprocessor result
      #
      # @return [Parser::AST::Node]
      #
      # @api private
      #
      abstract_method :result

      # Run preprocessor for node
      #
      # @param [Parser::AST::Node, nil] node
      #
      # @return [Parser::AST::Node, nil]
      #
      # @api private
      #
      def self.run(node)
        return if node.nil?
        REGISTRY.fetch(node.type, [Noop]).reduce(node) do |node, processor|
          processor.call(node)
        end
      end

      REGISTRY = Hash.new { |hash, key| hash[key] = [] }

      # Register preprocessor
      #
      # @param [Symbol] type
      #
      # @return [undefined]
      #
      # @api private
      #
      def self.register(type)
        REGISTRY[type] << self
      end
      private_class_method :register

    private

      # Visit node
      #
      # @param [Parser::AST::Node]
      #
      # @return [undefined]
      #
      # @api private
      #
      def visit(node)
        self.class.run(node)
      end

      # Return children
      #
      # @return [Array<Parser::AST::Node>]
      #
      # @api private
      #
      def children
        node.children
      end

      # Return visited children
      #
      # @return [Array<Parser::Ast::Node>]
      #
      # @api private
      #
      def visited_children
        children.map do |node|
          if node.kind_of?(Parser::AST::Node)
            visit(node)
          else
            node
          end
        end
      end

      # Noop preprocessor that just passes through noode.
      class Noop < self

        register :int
        register :str

        # Return preprocessor result
        #
        # @return [Parser::AST::Node]
        #
        # @api private
        #
        def result
          s(node.type, visited_children)
        end

      end # Noop

      # Preprocessor for dynamic string nodes. Collapses adjacent string segments into one.
      class CollapseStrChildren < self

        register :dstr
        register :regexp
        register :xstr

        # Return preprocessor result
        #
        # @return [Parser::AST::Node]
        #
        # @api private
        #
        def result
          if collapsed_children.all? { |node| node.type == :str }
            s(:str, [collapsed_children.map { |node| node.children.first }.join])
          else
            node.updated(nil, collapsed_children)
          end
        end

      private

        # Return collapsed children
        #
        # @return [Array<Parser::AST::Node>]
        #
        # @api private
        #
        def collapsed_children
          chunked_children.each_with_object([]) do |(type, nodes), aggregate|
            if type == :str
              aggregate << s(:str, [nodes.map { |node| node.children.first }.join])
            else
              aggregate.concat(nodes)
            end
          end
        end
        memoize :collapsed_children

        # Return chunked children
        #
        # @return [Array<Parser::AST::Node>]
        #
        # @api private
        #
        def chunked_children
          visited_children.chunk(&:type)
        end

      end # Begin

      # Preprocessor for regexp nodes. Normalizes quoting.
      class Regexp < self

        register :regexp

        # Return preprocesso result
        #
        # @return [Parser::AST::Node]
        #
        # @api private
        #
        def result
          location = node.location
          if location && location.begin.source.start_with?('%r')
            s(:regexp, correctly_quoted_children)
          else
            node
          end
        end

        # Return correctly quoted children
        #
        # @return [Array<Parser::AST::Node>]
        #
        # @api private
        #
        def correctly_quoted_children
          visited_children.map do |child|
            if child.type == :str
              quote_str_child(child)
            else
              child
            end
          end
        end

        # Quote child correctly
        #
        # @param [Parser::AST::Node] node
        #
        # @return [Parser::AST::Node] node
        #
        # @api private
        #
        def quote_str_child(child)
          original = child.children.first
          modified = Unparser.transquote(child.children.first, ')', '/')
          s(:str, [modified])
        end
      end

      # Preprocessor for begin nodes. Removes begin nodes with one child.
      #
      # These superflownosely currently get generated by unparser.
      #
      class Begin < self

        register :begin

        # Return preprocessor result
        #
        # @return [Parser::AST::Node]
        #
        # @api private
        #
        def result
          if children.one?
            visit(children.first)
          else
            Noop.call(node)
          end
        end

      end # Begin
    end # Preprocessor
  end # CLI
end # Unparser
