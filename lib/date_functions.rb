require 'date'

class DateFunctions

  # Simple validation of a date given in YYYY-MM-DD format
  def self.valid_date(date)
    begin
      Date.parse(date, "%Y-%m-%d")
    rescue ArgumentError
      raise ArgumentError.new("'#{date}' is an invalid date.")
    end
  end

  # Return a string represenation (format YYYY-MM-DD) of 
  # today + '(+/-)diff' number of days.
  # This simple version uses localtime (not UTC)
  def self.day_diff(diff)
    return (Time.now.localtime+(diff).day).strftime("%Y-%m-%d")
  end

end