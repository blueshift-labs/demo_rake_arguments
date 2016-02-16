namespace :stats do

  desc "Compute pageload statistics for a list of sites and a given window of time"
  task :pageloads, [:params] => :environment do |t, args|  
    # Parse the arguments, either from ARGV in case of direct invocation
    # or from args[:params] in the case it was called from other rake_tasks
    parameters = RakeTaskArguments.parse_arguments(t.name, "--sites=<list> "\
      "[ (--start-date=<start-date> --end-date=<end-date>) | (--days-ago=<n> [--days-ago-end=<k>]) ]", 
       args[:params].nil? ? ARGV : args[:params])
    # Get the list of sites
    sites = parameters["sites"]
    # Validate and process the start and end date input
    start_date, end_date = RakeTaskArguments.get_dates_start_end(parameters["start-date"], parameters["end-date"], 
      parameters["days-ago"], 0, parameters["days-ago-end"])
    # For each of the sites
    sites.split(',').each do |site|
      # Pretend to do something meaningful
      puts "Computing pageload stats for site='#{site}' for dates between #{start_date} and #{end_date}"
    end # End site loop
  end

  desc "Compute click statistics for a list of sites and a given window of time"
  task :clicks, [:params] => :environment do |t, args|  
    # Parse the arguments, either from ARGV in case of direct invocation
    # or from args[:params] in the case it was called from other rake_tasks
    parameters = RakeTaskArguments.parse_arguments(t.name, "--sites=<list> "\
      "[ (--start-date=<start-date> --end-date=<end-date>) | (--days-ago=<n> [--days-ago-end=<k>]) ]", 
       args[:params].nil? ? ARGV : args[:params])
    # Get the list of sites
    sites = parameters["sites"]
    # Validate and process the start and end date input
    start_date, end_date = RakeTaskArguments.get_dates_start_end(parameters["start-date"], parameters["end-date"], 
      parameters["days-ago"], 0, parameters["days-ago-end"])
    # For each of the sites
    sites.split(',').each do |site|
      # Pretend to do something meaningful
      puts "Computing clicks stats for site='#{site}' for dates between #{start_date} and #{end_date}"
    end # End site loop
  end

  desc "Run multiple aggregate computations for a given list of sites and a given window of time"
  task :multi, [:params] => :environment do |t, args|  
    # Parse the arguments, either from ARGV in case of direct invocation
    # or from args[:params] in the case it was called from other rake_tasks
    parameters = RakeTaskArguments.parse_arguments(t.name, "--sites=<list> [--aggregates=<list>] "\
      "[ (--start-date=<start-date> --end-date=<end-date>) | (--days-ago=<n> [--days-ago-end=<k>]) ]", 
       args[:params].nil? ? ARGV : args[:params])
    # Get the list of sites
    sites = parameters["sites"]
    # Just for demo purposes, you would normally fetch this elsewhere
    available_aggregates = ["pageloads", "clicks"]
    # Fetch the list of
    aggregates = parameters["aggregates"].nil? ? available_aggregates.join(",") :
      RakeTaskArguments.validate_values(parameters["aggregates"], available_aggregates)
    # Validate and process the start and end date input
    start_date, end_date = RakeTaskArguments.get_dates_start_end(parameters["start-date"], parameters["end-date"], 
      parameters["days-ago"], 0, parameters["days-ago-end"])
    # For each of the sites
    sites.split(',').each do |site|
      # For each of the tables
      aggregates.split(',').each do |aggregate|
        # Prepare an array with values to pass to the sub rake-tasks
        parameters = []
        parameters.push("stats:#{aggregate}")
        parameters.push("--sites=#{site}") # just one single site
        parameters.push("--start-date=#{start_date}")
        parameters.push("--end-date=#{end_date}")
        self.execute_rake("stats", aggregate, parameters)
      end
    end # End site loop
  end

  # Helper method for invoking and re-enabling rake tasks
  def self.execute_rake(namespace, task_name, parameters)
    # Invoke the actual rake task with the given arguments
    Rake::Task["#{namespace}:#{task_name}"].invoke(parameters)
    # Re-enable the rake task in case it is being for different parameters (e.g. in a loop)
    Rake::Task["#{namespace}:#{task_name}"].reenable
  end

end