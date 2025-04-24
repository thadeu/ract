# frozen_string_literal: true

# frozen_string_literal: true # :rdoc

class Ract
  class Executor
    class IsolatedAbstract
      def initialize(...)
        raise NotImplementedError
      end

      def run(&)
        raise NotImplementedError
      end
    end
  end
end
