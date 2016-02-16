## Passing named arguments to Ruby Rake tasks using docopt for data science pipelines

<!-- MarkdownTOC -->

- [Introduction](#introduction)
- [Configuring your Rails project to use `docopt`](#configuring-your-rails-project-to-use-docopt)
- [Anatomy of the argument specification string](#anatomy-of-the-argument-specification-string)
  - [Basic rules](#basic-rules)
  - [Optional arguments](#optional-arguments)
  - [Grouping and mutual exclusion](#grouping-and-mutual-exclusion)
  - [Flags](#flags)
- [`RakeTaskArguments`](#raketaskarguments)
  - [the solo `--` (double dash) that keeps coming back](#the-solo----double-dash-that-keeps-coming-back)
- [Rake task with named arguments](#rake-task-with-named-arguments)
- [Rake task calling other rake tasks](#rake-task-calling-other-rake-tasks)
- [Conclusion](#conclusion)
- [References](#references)

<!-- /MarkdownTOC -->

### Introduction

Ever considered using `rake` for running tasks, but got stuck with the unnatural way that rake tasks pass in the arguments? Or have you seen the fancy argument parsing `docopt` and alikes can do for you? This article describes how we integrated [docopt](http://docopt.org/) with the `rake` command so we can launch our data science pipelines using commands like this:

    $ bundle exec rake stats:multi -- --sites=foo.com,bar.com \
        --aggregates=pageloads,clicks \
        --days-ago=7 --days-ago-end=0 

This command would for instance launch daily aggregate computations for `clicks` and  `pageloads`, for each of the sites `foo.com` and `bar.com`, and this for each individual day in the last 7 days.

Not only can you launch your tasks using descriptive arguments, you get automated argument validation on top of it. Suppose we launch the task using the following command:

    $ bundle exec rake stats:multi

Then the task would fail with the following help message 

    Usage: stats:multi -- --sites=<list> \
                          [--aggregates=<list>] \
                          [ (--start-date=<start-date> --end-date=<end-date>) | \
                            (--days-ago=<n> [--days-ago-end=<k>]) ]
           stats:multi -- --help

It will display the mandatory and/or optional arguments and the possible combinations (e.g. mutually exclusive arguments). And the best thing of all is that all you have to do to obtain this advanced validation, is merely specifying the string just like the one you are seeing here: indeed, `docopt` uses your specification of the help message to process all you wish for your arguments!

The remainder of this post will explain how to set this up yourself and how to use it. This guide assumes you have successfully configured your system for using ruby and rails and the `bundle` command. Here are guides on how to set up [RVM](https://rvm.io/) and [getting started with Rails](http://guides.rubyonrails.org/getting_started.html).

### Configuring your Rails project to use `docopt`

[docopt](http://docopt.org/) is an argument parsing library available for many different languages. For more details, on what it does, have a look at the [documentation here](https://github.com/docopt/docopt.rb). We use it as a [Ruby gem](https://github.com/docopt/docopt.rb). You can simply add it to your project by editing your `Gemfile` in your project root by adding:

    gem 'docopt', '0.5.0'

Then run

    $ bundle install

in your project directory. This should be sufficient to make your project capable of using the `docopt` features.

### Anatomy of the argument specification string

First, we should elaborate a bit how `docopt` knows what to expect and how to parse/validate your input. To make this work, you are expected to present `docopt` with a string that follows certain rules. As mentioned above, this is also the string that is being show as the help text. More specific, what it expects is a string that follows the following schema:

    Usage: #{program_name} -- #{argument_spec}
           #{program_name} -- --help

where `program_name` equals to the name of the command that is being run, `--` (double dash) - this is not due to `doctopt` but due to rake (more on that in a moment), and `argument_spec` which can be anything you want to put there.

Let's look at the aforementioned example:

    Usage: stats:multi -- --sites=<list> \
                          [--aggregates=<list>] \
                          [ (--start-date=<start-date> --end-date=<end-date>) | \
                            (--days-ago=<n> [--days-ago-end=<k>]) ]

Here, the `program_name` is `stats:multi`, which is the actual namespace and task name for our rake task, '--' and the `argument_spec` is `"--sites=<list> [--aggregates=<list>] [ (--start-date=<start-date> --end-date=<end-date>) | (--days-ago=<n> [--days-ago-end=<k>]) ]"`

Now, let's go into details of the `argument_spec` (split over multiple lines for readability):

    --sites=<list> \
    [--aggregates=<list>] \
    [ (--start-date=<start-date> --end-date=<end-date>) | \
      (--days-ago=<n> [--days-ago-end=<k>]) ]

#### Basic rules

`docopt` considers arguments mandatory, unless they are enclosed in brackets `[]` - then they are optional. So in this example, our only `--sites` is required. It also requires a value, given that it is being followed by `=<list>`. However, `<list>` here could be anything, and is used to give the user an idea of what is expected as the type of argument. If you would enter `--sites` on the input without specifying a value, `docopt` will return an error that the value is missing. No effort needed on your end!

#### Optional arguments

The next argument `[--aggregates=<list>]` follows the same pattern, except that this one is fully optional. We will in our code handly the case where this is not specified and come up with some default values.

#### Grouping and mutual exclusion

The last - optional - argument is used to specify the dates we want to run our computation for, and we want to have three ways of doing so this: 

* EITHER by specifically telling the `start-date` AND `end-date`
* OR by specifying the number of `days-ago` before the time of the command, taking as an end date the date of the command being run (e.g. 7 days ago until now)
* OR by specifying the number of `days-ago` until `days-ago-end` (e.g. to backfill something between 14 days ago and 7 days ago).

Here is where complicated things can be achieved in a simple manner. The formatting we used for this is in fact:

    [ ( a AND b) | ( c [ d ] ) ]

`docopt` requires __all__ arguments in a *group* `(...)` to be presented on the input. If only `a` or `b` are given, it will return and inform us about the missing argument.

Similarly, a logical __OR__ can be added via `|` (pipe). This will make either of the options a valid input.

Furthermore, you can combine optional arguments within a group, like we did with `( c [ d ] )`. This will make the parser aware of the fact that `d` (in the real example above `[--days-ago-end=<k>]`) is only valid when `c` (`--days-ago=<n>` in the example) has been presented. Trying to use this parameter with `--start-days` will result in an error.

Note that this whole complex group is __optional__ and we again will come up with some defaults in our code that handles the parsed arguments.

#### Flags

Lastly, it's noteworthy that `flags` (i.e. arguments that don't take a value), such as `--force`, will result in a `true/false` value after parsing.

For more information and examples, consult the [docopt documentation here](https://github.com/docopt/docopt.rb). However, the explanation above should get you already a long way.

### `RakeTaskArguments`

Now that you have understanding of how the argument string defines how your input will be parsed and/or be errored out, we can write a class that wraps all of this functionality together, and exposes us only to specifying this string and getting a map with the parsed values in return.

To this end, we wrote the `RakeTaskArguments.parse_arguments` method:

```
class RakeTaskArguments
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
end
```

The method takes 3 arguments:

* the rake `task_name` that we want to execute
* the `argument_spec` we discussed before
* the `args` actual input that was provided when launching the task and that should be validated.

Parsing and validation happens magically by

    Docopt::docopt(doc, {:argv => args})

while it returns a map with the keys and values for our input arguments. We iterate over the key-value pairs and strip the leading `--` (double dash - e.g. `--sites`) from the keys so we can access them in the resulting map later on via their name (e.g. `...['sites']` instead of `...['--sites']`), which is just more practical to deal with.

#### the solo `--` (double dash) that keeps coming back

We keep seeing this solo `--` floating around in the strings, like `stats:multi -- --sites=<list>`. As was pointed out [here on StackOverflow](http://stackoverflow.com/a/5086648/1803313), this is needed to make the actual `rake` command stop parse arguments. Indeed, without adding this `--` immediately after the rake task you want to execute, `rake` would consider the subsequent arguments to be related to `rake` itself. Therefore, we also have it in our `docopt` spec 

    #{task_name} -- #{argument_spec}

to make sure the library does not parse it out. It is inconvenient, but hacking this up this way has way more benefits if you get used to it.

__WARNING__: It seems that in rake version 10.3.x, this `--` was not passed along in the `ARGV` list, but the newer version of rake, 10.4.x __DOES__ pass it along. Therefore we added the following code:

    args.delete_at(1) if args.length >= 2 and args.second == '--'

which removes this item from the list before we pass it to `docopt`. Also note that this line of code removes the __second__ element from the list, as the __first__ element is always the __program name__.

### Rake task with named arguments

Once you have the `docopt` gem installed and the `RakeTaskArguments.rb` class available in your project, we can specify the following demo rake task:

```
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
end
``` 

This basic rake task follows a really simple and straightforward template. However, first we need to understand how this task get's it's input arguments. As briefly mentioned before, this task will receive the input in the `ARGV` variable in Ruby. However, when a rake task calls another rake task, this variable might not contain the correct information. Therefore we enable parameter passing into the task by defining the following header:

    task :pageloads, [:params] => :environment do |t, args|

This way, __IF__ this task was called from another task, `args` will contain a field called `:params` that contains the arguments that the parent task passed alogn to this task. A detailed example of that follows later on. This matters because we decide at runtime what *input* to pass to the argument validation. So, to pass the input for validation, we just call

    parameters = RakeTaskArguments.parse_arguments(t.name, "--sites=<list> "\
          "[ (--start-date=<start-date> --end-date=<end-date>) | (--days-ago=<n> [--days-ago-end=<k>]) ]", 
        args[:params].nil? ? ARGV : args[:params])

This command passes the `task_name` (via `t.name`), the argument specification and the input (either via `ARGV` or `args[:params]`) for validation to `docopt`. At this point, you are guaranteed that the `parameters` return value contains everything according to the schema you specified, or your code has already errored out at this point.

If you then want to access some of the variables, you can simply use

    sites = parameters["sites"]
    start_date, end_date = RakeTaskArguments.get_dates_start_end(parameters["start-date"], parameters["end-date"], 
      parameters["days-ago"], 0, parameters["days-ago-end"])

This last line sets up a `start-date` and `end-date` based on some validation and/or defaults we specified in a method that is not covered in this article. The code is available on github though.

### Rake task calling other rake tasks

Finally, we cover the case where a meta-task is actually invoking other tasks (in case you want to group certain computations). As mentioned above, this has an impact on how the arguments get passed into the task. Let's consider the following meta-task:

```
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
```

The template used in this task is very similar to a simple rake task. The main difference is that we added a list of `aggregates` you can specify on the input, which is validated against certain allowed values (again, out of the scope of this article). The `:multi` task then calls the appropriate tasks with the given parameters.

What's new here is the way the meta-task calls the other tasks:

```
    # Prepare an array with values to pass to the sub rake-tasks
    parameters = []
    parameters.push("stats:#{aggregate}")
    parameters.push("--sites=#{site}") # just one single site
    parameters.push("--start-date=#{start_date}")
    parameters.push("--end-date=#{end_date}")
    self.execute_rake("stats", aggregate, parameters)
```

Basically, we construct a list of arguments that emulates as if the input to the task was provided on the command line. We then call the other rake task using the following helper function:

```
  # Helper method for invoking and re-enabling rake tasks
  def self.execute_rake(namespace, task_name, parameters)
    # Invoke the actual rake task with the given arguments
    Rake::Task["#{namespace}:#{task_name}"].invoke(parameters)
    # Re-enable the rake task in case it is being for different parameters (e.g. in a loop)
    Rake::Task["#{namespace}:#{task_name}"].reenable
  end
```

As a rake task is generally intended to be run only once, invoking it again would have no effect. But as we launch the same tasks with different parameters, we can `reenable` the tasks for execution. This helper function shields us from these technicalities and we can just call the `execute` function with the namespace, the task name and the parameters. When Ruby calls `.invoke(parameters)` on a rake task, these parameters will end up in the `args[:params]` we discussed before.

### Conclusion

So, that concludes or extensive article on how to add a lot of flexibility to arguments you provide to rake. In the end, we covered

* How you can easily add `docopt` to a Rails project
* How `docopt` argument specification strings look like and how they work
* How you could write a wrapper class that encapsulates all that functionality
* How you can plug this into simple rake tasks
* How you can run *meta* rake tasks that call other tasks while keeping the flexbility for your input arguments

The full code and working examples of this article are available [here on GitHub-TODO](#).

We hope this article helps you to get something like this set up for your own stacks as well, and that it increases your productivity. If you have any comments, questions or suggestions, feel free to let us know!

### References

* The code for this article can be found on [GitHub-TODO](#)
* [docopt.rb documentation](https://github.com/docopt/docopt.rb)
* [rake documentation](https://github.com/ruby/rake)
* [Brief mention of the double dash issue with Rake](http://stackoverflow.com/a/5086648/1803313)
