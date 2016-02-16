class RakeTaskArguments

  # Docopt is capable of parsing ARGV from the shell, or in case ARGV is not available via a hash 
  # with a symbol named ':argv' whose format requires a certain command name to be issued - 
  # in this case 'task_name'.
  # The argument immediately after the command name, should be '--' in order to avoid that
  # rake will consider the subsequent arguments to be rake arguments, (as pointed out 
  # here: http://stackoverflow.com/a/5086648/1803313).
  #
  # This function will take the rake task name you want to execute, the argument specification
  # and then the actual input. It will construct the input as if it was original input from the
  # shell into docopt, and have it parsed and validated.
  # The input arguments should be prefixed with '--', e.g. '--SOME-NAME'. Once parsed, the
  # prefix will be removed and the value will be available in the output by a new key like 'SOME-NAME'.
  # In case of a flag (e.g. '--upload'), which does not require a value, the final hash
  # will contain 'arguments["upload"] = true or false' when the flag was or was not provided on
  # input respectively. 
  #
  # Docopt works fairly simple: by providing the 'help text' or 'usage string', it is capable of
  # figuring out what parameter combinations are valid or not, what is required, mutually exclusive,
  # what requires a value or is a flag.
  def self.parse_arguments(task_name, argument_spec, args)  
    # Set up the docopt string that will be used to pass the input along
    doc = <<DOCOPT
Usage: #{task_name} -- #{argument_spec}
       #{task_name} -- --help
DOCOPT
    # Prepare the return value
    arguments = {}
    begin
      # Because the new version of rake passes the -- along in the args variable,
      # we need to filter it out if it's present
      args.delete_at(1) if args.length >= 2 and args.second == '--'
      # Have docopt parse the provided args (via :argv) against the doc spec
      Docopt::docopt(doc, {:argv => args}).each do |key, value|
        # Store key/value, converting '--key' into 'key' for accessability
        # Per docopt pec, the key '--' contains the actual task name as a value
        # so we label it accordingly
        arguments[key == "--" ? 'task_name' : key.gsub('--', '')] = value
      end
    rescue Docopt::Exit => e
      abort(e.message)
    end
    return arguments
  end 

  # Validate the provided values against a list of valid values
  # Returns the input values in case all values are valid, or 
  # exit in case of invalid input
  def self.validate_values(input_values, valid_values, allow_multiple = true)
    list_valid_values = valid_values
    list_valid_values = list_valid_values.split(',') if !list_valid_values.kind_of?(Array)
    begin
      # Check for empty list
      if input_values.blank?
        raise ArgumentError.new("An empty value was provided.")
      end
      list_input_values = input_values.split(',')
      # Check for multiple items while only one was allowed
      if !allow_multiple && list_input_values.length > 1
        raise ArgumentError.new("Multiple input values were provided: '#{list_input_values}', "\
          "while only one of these can be used: #{list_valid_values}.")
      end
      # Check each of the provided values
      list_input_values.each do |value|
        # Check if the value is a valid value
        if !list_valid_values.include? value
          raise ArgumentError.new("An invalid value was provided: '#{value}'.\nValid values are: #{list_valid_values}.")
        end
      end
    rescue ArgumentError => e
      abort(e.message)
    end
    return input_values
  end

  # Returns the value in case this is an integer, exits otherwise
  def self.validate_integer(value)
    begin
      if !self.is_integer?(value)
        raise ArgumentError.new("'#{value}' is not a valid integer argument.")
      end
    rescue ArgumentError => e
      abort(e.message)
    end
    return value
  end

  # Return true if the given string represents a valid integer
  def self.is_integer? (string)
    true if Integer(string) rescue false
  end

  # Function that validates input dates for a typical timespan window between a begin and end date.
  # Returns begin and end date in case of valid input, or exits otherwise
  def self.get_dates_start_end(start_date, end_date, days_ago, default_days_ago, days_ago_end = nil)
    begin
      # No dates are given, so we use either day differences or defaults
      if start_date.nil? && end_date.nil?
        # Figure out how many days ago the begin date is, if nil we use default
        diff_begin = days_ago.nil? ? validate_integer(default_days_ago).to_i : validate_integer(days_ago).to_i
        # Figure out how many days ago the end date is, if nil we use today (0)
        diff_end = days_ago_end.nil? ? 0 : validate_integer(days_ago_end).to_i
        # Establish begin and end date
        start_date = DateFunctions.day_diff(-diff_begin)
        end_date = DateFunctions.day_diff(-diff_end)
      # Dates are given
      else
        # Validate the given dates
        start_date = DateFunctions.valid_date(start_date)
        end_date = DateFunctions.valid_date(end_date)
      end
    rescue ArgumentError => e
      abort(e.message)
    end
    return start_date, end_date
  end
end
