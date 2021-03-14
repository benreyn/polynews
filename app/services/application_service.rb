# frozen_string_literal: true

class ApplicationService
  def self.call(...)
    new(...).call
  end

  def success(details = nil)
    OpenStruct.new({success?: true, details: details})
  end

  def failure(error)
    OpenStruct.new({success?: false, error: error})
  end
end
