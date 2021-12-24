require "eis/error"

module EIS
  ##
  # = Service Hub
  # A hub holding services. Which could struct parameter array.
  #
  # It is designed to relace the mess member variables and class instance
  # varibles in both ElfMan and Core.
  # == Example
  #   svchub = EIS::SvcHub.new()
  #   foosvc = Foo.new
  #   svchub.regsvc foosvc
  #   svchub.acsvc Bar
  #   # Bar is a class which depends on Foo
  #   app = svchub.di FooBar
  #   # FooBar is a application depends on these service
  class SvcHub
    def initialize
      @svcs = {"svc_hub" => self}
    end

    ##
    # = Register Service
    # Register a instanced service class.
    #
    # == Parameters
    # +inst+:: An instanced class needs to register.
    #
    # == Return
    # The service instance registered itself.
    def register_service inst
      name = inst.class.to_s.underscore.gsub "eis/", ""
      if @svcs.has_key? name
        raise OperationViolationError.new(
          "register #{inst.class}",
          "same class already exist",
          self
        )
      end
      @svcs[name] = inst
    end

    alias_method :regsvc, :register_service

    def delete_service name
      @svcs.delete name
    end

    alias_method :delsvc, :delete_service

    def service name
      name = inst.class.to_s.underscore.gsub("eis/", "") unless name.is_a? ::String
      @svcs[name]
    end

    alias_method :svc, :service

    ##
    # = Build Parameter Array For Specified Function
    # Accept a function, build the parameter(injections) based on the
    # registered services.
    #
    # == Parameters
    # +func+:: The function needs injections.
    #
    # == Exceptions
    # +EIS::OperationViolationError+, raised if the parameter is not
    # :req or service have not been registered.
    #
    # == Example
    #
    #   para = svchub.build_param_for foo.method(:bar)
    #   foo.bar para
    def build_param_for func
      result = []
      func.parameters.each do |para|
        next unless para[0] == :req
        unless @svcs.include? para[1].to_s
          raise OperationViolationError.new(
            "arraylize parameter #{para[1]}",
            "service #{para[1]} have not exist!",
            self
          )
        end
        puts "Built #{para[1]} = #{@svcs[para[1].to_s]}" if EIS::Core.eis_debug
        result << @svcs[para[1].to_s]
      end
      result
    end

    alias_method :bldpara, :build_param_for

    def auto_config_service_for cls
      inst = cls.new(*build_param_for(cls.instance_method(:initialize)))
      register_service inst
    end

    alias_method :acsvc, :auto_config_service_for

    def dependencies_inject_into cls
      cls.new(*bldpara(cls.instance_method(:initialize)))
    end

    alias_method :di, :dependencies_inject_into
  end
end
