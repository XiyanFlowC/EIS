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
      "ArgumentError: Argument #{argument_name} is incorrect, because: #{reason}"
    end
  end

  class DataMismatchError < ArgumentError
    attr_reader :arg, :vali

    def initialize(arg, vali)
      super(arg, "#{vali} mismatch.")
      @vali = vali
    end

    def to_s
      "DataMismatchError: Argument #{@arg} is mismatch with #{@vali}."
    end
  end

  class DataCorruptedError < EISError
    attr_reader :data_name, :desc

    def initialize data_name, desc
      @data_name = data_name
      @desc = desc
    end

    def to_s
      "DataCorruptedError: Data #{@data_name} is corrupted. (#{@desc})"
    end
  end
end
