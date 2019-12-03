module Gruf
  module StackdriverTrace
    module Label
      def label_key
        Google::Cloud::Trace::LabelKey
      end

      def set_label(labels, key, value)
        labels[key] = value.to_s
      end
    end
  end
end
