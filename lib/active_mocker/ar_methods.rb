module ActiveMocker

  module ARMethods
    extend ActiveSupport::Concern

    included do
    end

    module ClassMethods
      def exclude_module(options = {})
        # your code will go here
      end
    end
  end
end

ActiveRecord::Base.send :include, ActiveMocker::ARMethods