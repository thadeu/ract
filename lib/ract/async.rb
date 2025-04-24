# frozen_string_literal: true

# frozen_string_literal: true # :rdoc

class Ract
  module Async
    def self.included(base)
      base.include(ClassMethods)
    end

    def self.extended(base)
      base.extend(ClassMethods)
    end

    def Ract(&)
      Ract.new(&)
    end

    module ClassMethods
      def ract(&)
        Ract(&)
      end

      def async(method_name)
        if method_defined?(method_name)
          original_method = instance_method(method_name)

          define_method("#{method_name}_async") do |*args, **kwargs, &block|
            Ract { original_method.bind(self).call(*args, **kwargs, &block) }
          end
        elsif singleton_methods.include?(method_name)
          define_singleton_method("#{method_name}_async") do |*args, **kwargs, &block|
            Ract { send(method_name, *args, **kwargs, &block) }
          end
        end
      end
    end
  end
end
