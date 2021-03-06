require "msgpack"

module Plugal
  # Returns all defined commands in this application as an `Array(String)`
  def commands
    {{Plugal::Commands.subclasses.map &.name.stringify}}
  end

  # Wrappes the result data and includes error information.
  #
  class Result(T)
    enum Value
      Success
      Error
    end

    # :nodoc:
    MessagePack.mapping({
        result: Value,
        message: String?,
        data: String
    })

    def initialize(data : T, @result : Value = Value::Success, @message : String = "")
      @data = data.to_msgpack
    end

    def success(&block : T -> _)
      yield @data
    end

    def error(&block : {Value, String, T} -> _)
      yield @result, @message, @data
    end

    def all(&block : {Value, String, T} -> _)
      yield @result, @message, @data
    end
  end

  # Defines a new command.
  #
  # It will automatically subclass `Plugal::Command`,
  # provide a `JSON` mapping and create an initializer for all properties.
  # This initializer is also used internally.
  #
  # The *name* argument can be a `String` or `Symbol`. As this macro essentially creates a struct
  # *name* will be capitalized and **Command** appended.
  # ```crystal
  # Plugal.command :love, ... # => LoveCommand
  # ```
  #
  # The *args* argument defines the arguments for your command. They should be defined like for `JSON.mapping`.
  # You can also use a `Hash`.
  # ```crystal
  # Plugal.command :love, me: String, age: UInt32
  # ```
  #
  # The *result* argument defines what type should be returned by the block in `Receiver#provide` and stored in `Result`.
  macro command(name, args, result)
    struct {{name.capitalize.id}}Command < Plugal::Command
      {% for key, value in args %}
        {% args[key] = {type: value} unless value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) %}
      {% end %}

      {% args[:result] = {type: "Plugal::Result(#{result})".id, nilable: true} %}
      private def _result_{{result}}
      end

      {% for key, value in args %}
        {% unless key.id == "result" %}
          private def _arg_{{key.id}}_{{value[:type].resolve.name.downcase.id}} 
          end
        {% end %}
      {% end %}

      {% args[:name] = {type: String} %}

      def initialize(**args)
        i = 0
        
        {% for key, value in args %}
          {% if key.id == "name" %}
            @name = {{name.id.stringify}}
          {% elsif key.id == "result" %}
            @result = if result = args[:result]?
                        result
                      else
                        nil
                      end 
          {% else %}
            @{{key.id}} = args[:{{key.id}}]            
            i += 1
          {% end %}
        {% end %}            
      end

      MessagePack.mapping({{args}})
      
      {{yield}}
    end
  end

  # Wrapper for named arguments.
  #
  # Makes it possible to define the arguments as named arguments instead of using a `Hash`.
  # For more information check `#command(name, args, result)`
  macro command(name, **args, result)
    ::Plugal.command({{name}}, {{args}}, {{result}})
  end

  # An abstract struct to bring the commands together
  #
  # Its only purpose is to make the macro magic work by bringing all commands under one roof.
  abstract struct Command
  end
end