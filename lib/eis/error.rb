module EIS
  ##
  # EIS Error type, raised by EIS module. It's just an Empty child
  # of StandardError
  class EISError < StandardError
  end

  ##
  # ArgumentError, raised when an unexpected value be passed to
  # routine.
  #
  # = Attributes
  # * _reason_: *readonly* the reason why this error be raised
  # * _argument_name_: *readonly* the argument name which has error
  # be detected.
  class ArgumentError < EISError
    attr_reader :reason, :argument_name

    def initialize(argument_name, reason)
      @argument_name = argument_name
      @reason = reason
    end

    ##
    # An default description to this error
    def to_s
      "Argument #{argument_name} is incorrect, because: #{reason}"
    end
  end
end
