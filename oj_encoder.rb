require "oj"

class OjEncoder
  def initialize
    ::Oj.default_options = {mode: :compat}
  end

  def encode(value)
    ::Oj.dump(value)
  end
end
