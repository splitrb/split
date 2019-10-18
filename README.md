# [Split](https://libraries.io/rubygems/split)

[![Gem Version](https://badge.fury.io/rb/split.svg)](http://badge.fury.io/rb/split)
[![Build Status](https://secure.travis-ci.org/splitrb/split.svg?branch=master)](https://travis-ci.org/splitrb/split)
[![Code Climate](https://codeclimate.com/github/splitrb/split/badges/gpa.svg)](https://codeclimate.com/github/splitrb/split)
[![Test Coverage](https://codeclimate.com/github/splitrb/split/badges/coverage.svg)](https://codeclimate.com/github/splitrb/split/coverage)
[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)
[![Open Source Helpers](https://www.codetriage.com/splitrb/split/badges/users.svg)](https://www.codetriage.com/splitrb/split)

> 📈 The Rack Based A/B testing framework https://libraries.io/rubygems/split

Split is a rack based A/B testing framework designed to work with Rails, Sinatra or any other rack based app.

Split is heavily inspired by the [Abingo](https://github.com/ryanb/abingo) and [Vanity](https://github.com/assaf/vanity) Rails A/B testing plugins and [Resque](https://github.com/resque/resque) in its use of Redis.

Split is designed to be hacker friendly, allowing for maximum customisation and extensibility.

## Install

### Requirements

Split currently requires Ruby 1.9.3 or higher. If your project requires compatibility with Ruby 1.8.x and Rails 2.3, please use v0.8.0.

Split uses Redis as a datastore.

Split only supports Redis 2.0 or greater.

If you're on OS X, Homebrew is the simplest way to install Redis:

```bash
brew install redis
redis-server /usr/local/etc/redis.conf
```

You now have a Redis daemon running on port `6379`.

### Setup

```bash
gem install split
```

#### Rails

Adding `gem 'split'` to your Gemfile will autoload it when rails starts up, as long as you've configured Redis it will 'just work'.

#### Sinatra

To configure Sinatra with Split you need to enable sessions and mix in the helper methods. Add the following lines at the top of your Sinatra app:

```ruby
require 'split'

class MySinatraApp < Sinatra::Base
  enable :sessions
  helpers Split::Helper

  get '/' do
  ...
end
```

## Usage

To begin your A/B test use the `ab_test` method, naming your experiment with the first argument and then the different alternatives which you wish to test on as the other arguments.

`ab_test` returns one of the alternatives, if a user has already seen that test they will get the same alternative as before, which you can use to split your code on.

It can be used to render different templates, show different text or any other case based logic.

`ab_finished` is used to make a completion of an experiment, or conversion.

Example: View

```erb
<% ab_test(:login_button, "/images/button1.jpg", "/images/button2.jpg") do |button_file| %>
  <%= image_tag(button_file, alt: "Login!") %>
<% end %>
```

Example: Controller

```ruby
def register_new_user
  # See what level of free points maximizes users' decision to buy replacement points.
  @starter_points = ab_test(:new_user_free_points, '100', '200', '300')
end
```

Example: Conversion tracking (in a controller!)

```ruby
def buy_new_points
  # some business logic
  ab_finished(:new_user_free_points)
end
```

Example: Conversion tracking (in a view)

```erb
Thanks for signing up, dude! <% ab_finished(:signup_page_redesign) %>
```

You can find more examples, tutorials and guides on the [wiki](https://github.com/splitrb/split/wiki).

## Statistical Validity

Split has two options for you to use to determine which alternative is the best.

The first option (default on the dashboard) uses a z test (n>30) for the difference between your control and alternative conversion rates to calculate statistical significance. This test will tell you whether an alternative is better or worse than your control, but it will not distinguish between which alternative is the best in an experiment with multiple alternatives. Split will only tell you if your experiment is 90%, 95%, or 99% significant, and this test only works if you have more than 30 participants and 5 conversions for each branch.

As per this [blog post](https://www.evanmiller.org/how-not-to-run-an-ab-test.html) on the pitfalls of A/B testing, it is highly recommended that you determine your requisite sample size for each branch before running the experiment. Otherwise, you'll have an increased rate of false positives (experiments which show a significant effect where really there is none).

[Here](https://www.evanmiller.org/ab-testing/sample-size.html) is a sample size calculator for your convenience.

The second option uses simulations from a beta distribution to determine the probability that the given alternative is the winner compared to all other alternatives. You can view these probabilities by clicking on the drop-down menu labeled "Confidence." This option should be used when the experiment has more than just 1 control and 1 alternative. It can also be used for a simple, 2-alternative A/B test.

Calculating the beta-distribution simulations for a large number of experiments can be slow, so the results are cached. You can specify how often they should be recalculated (the default is once per day).

```ruby
Split.configure do |config|
  config.winning_alternative_recalculation_interval = 3600 # 1 hour
end
```

## Extras

### Weighted alternatives

Perhaps you only want to show an alternative to 10% of your visitors because it is very experimental or not yet fully load tested.

To do this you can pass a weight with each alternative in the following ways:

```ruby
ab_test(:homepage_design, {'Old' => 18}, {'New' => 2})

ab_test(:homepage_design, 'Old', {'New' => 1.0/9})

ab_test(:homepage_design, {'Old' => 9}, 'New')
```

This will only show the new alternative to visitors 1 in 10 times, the default weight for an alternative is 1.

### Overriding alternatives

For development and testing, you may wish to force your app to always return an alternative.
You can do this by passing it as a parameter in the url.

If you have an experiment called `button_color` with alternatives called `red` and `blue` used on your homepage, a url such as:

    http://myawesomesite.com?ab_test[button_color]=red

will always have red buttons. This won't be stored in your session or count towards to results, unless you set the `store_override` configuration option.

In the event you want to disable all tests without having to know the individual experiment names, add a `SPLIT_DISABLE` query parameter.

    http://myawesomesite.com?SPLIT_DISABLE=true

It is not required to send `SPLIT_DISABLE=false` to activate Split.


### Rspec Helper
To aid testing with RSpec, write `spec/support/split_helper.rb` and call `use_ab_test(alternatives_by_experiment)` in your specs as instructed below:

```ruby
# Create a file with these contents at 'spec/support/split_helper.rb'
# and ensure it is `require`d in your rails_helper.rb or spec_helper.rb
module SplitHelper

  # Force a specific experiment alternative to always be returned:
  #   use_ab_test(signup_form: "single_page")
  #
  # Force alternatives for multiple experiments:
  #   use_ab_test(signup_form: "single_page", pricing: "show_enterprise_prices")
  #
  def use_ab_test(alternatives_by_experiment)
    allow_any_instance_of(Split::Helper).to receive(:ab_test) do |_receiver, experiment|
      alternatives_by_experiment.fetch(experiment) { |key| raise "Unknown experiment '#{key}'" }
    end
  end
end

# Make the `use_ab_test` method available to all specs:
RSpec.configure do |config|
  config.include SplitHelper
end
```

Now you can call `use_ab_test(alternatives_by_experiment)`  in your specs, for example:
```ruby
it "registers using experimental signup" do
  use_ab_test experiment_name: "alternative_name"
  post "/signups"
  ...
end
```


### Starting experiments manually

By default new A/B tests will be active right after deployment. In case you would like to start new test a while after
the deploy, you can do it by setting the `start_manually` configuration option to `true`.

After choosing this option tests won't be started right after deploy, but after pressing the `Start` button in Split admin dashboard.  If a test is deleted from the Split dashboard, then it can only be started after pressing the `Start` button whenever being re-initialized.

### Reset after completion

When a user completes a test their session is reset so that they may start the test again in the future.

To stop this behaviour you can pass the following option to the `ab_finished` method:

```ruby
ab_finished(:experiment_name, reset: false)
```

The user will then always see the alternative they started with.

Any old unfinished experiment key will be deleted from the user's data storage if the experiment had been removed or is over and a winner had been chosen. This allows a user to enroll into any new experiment in cases when the `allow_multiple_experiments` config option is set to `false`.

### Reset experiments manually

By default Split automatically resets the experiment whenever it detects the configuration for an experiment has changed (e.g. you call `ab_test` with different alternatives). You can prevent this by setting the option `reset_manually` to `true`.

You may want to do this when you want to change something, like the variants' names, the metadata about an experiment, etc. without resetting everything.

### Multiple experiments at once

By default Split will avoid users participating in multiple experiments at once. This means you are less likely to skew results by adding in more variation to your tests.

To stop this behaviour and allow users to participate in multiple experiments at once set the `allow_multiple_experiments` config option to true like so:

```ruby
Split.configure do |config|
  config.allow_multiple_experiments = true
end
```

This will allow the user to participate in any number of experiments and belong to any alternative in each experiment. This has the possible downside of a variation in one experiment influencing the outcome of another.

To address this, setting the `allow_multiple_experiments` config option to 'control' like so:
```ruby
Split.configure do |config|
  config.allow_multiple_experiments = 'control'
end
```

For this to work, each and every experiment you define must have an alternative named 'control'. This will allow the user to participate in multiple experiments as long as the user belongs to the alternative 'control' in each experiment. As soon as the user belongs to an alternative named something other than 'control' the user may not participate in any more experiments. Calling ab_test(<other experiments>) will always return the first alternative without adding the user to that experiment.

### Experiment Persistence

Split comes with three built-in persistence adapters for storing users and the alternatives they've been given for each experiment.

By default Split will store the tests for each user in the session.

You can optionally configure Split to use a cookie, Redis, or any custom adapter of your choosing.

#### Cookies

```ruby
Split.configure do |config|
  config.persistence = :cookie
end
```

By default, cookies will expire in 1 year. To change that, set the `persistence_cookie_length` in the configuration (unit of time in seconds).

```ruby
Split.configure do |config|
  config.persistence = :cookie
  config.persistence_cookie_length = 2592000 # 30 days
end
```

__Note:__ Using cookies depends on `ActionDispatch::Cookies` or any identical API

#### Redis

Using Redis will allow ab_users to persist across sessions or machines.

```ruby
Split.configure do |config|
  config.persistence = Split::Persistence::RedisAdapter.with_config(lookup_by: -> (context) { context.current_user_id })
  # Equivalent
  # config.persistence = Split::Persistence::RedisAdapter.with_config(lookup_by: :current_user_id)
end
```

Options:
* `lookup_by`: method to invoke per request for uniquely identifying ab_users (mandatory configuration)
* `namespace`: separate namespace to store these persisted values (default "persistence")
* `expire_seconds`: sets TTL for user key. (if a user is in multiple experiments most recent update will reset TTL for all their assignments)

#### Dual Adapter

The Dual Adapter allows the use of different persistence adapters for logged-in and logged-out users. A common use case is to use Redis for logged-in users and Cookies for logged-out users.

```ruby
cookie_adapter = Split::Persistence::CookieAdapter
redis_adapter = Split::Persistence::RedisAdapter.with_config(
    lookup_by: -> (context) { context.send(:current_user).try(:id) },
    expire_seconds: 2592000)

Split.configure do |config|
  config.persistence = Split::Persistence::DualAdapter.with_config(
      logged_in: -> (context) { !context.send(:current_user).try(:id).nil? },
      logged_in_adapter: redis_adapter,
      logged_out_adapter: cookie_adapter)
  config.persistence_cookie_length = 2592000 # 30 days
end
```

#### Custom Adapter

Your custom adapter needs to implement the same API as existing adapters.
See `Split::Persistence::CookieAdapter` or `Split::Persistence::SessionAdapter` for a starting point.

```ruby
Split.configure do |config|
  config.persistence = YourCustomAdapterClass
end
```

### Trial Event Hooks

You can define methods that will be called at the same time as experiment
alternative participation and goal completion.

For example:

``` ruby
Split.configure do |config|
  config.on_trial  = :log_trial # run on every trial
  config.on_trial_choose   = :log_trial_choose # run on trials with new users only
  config.on_trial_complete = :log_trial_complete
end
```

Set these attributes to a method name available in the same context as the
`ab_test` method. These methods should accept one argument, a `Trial` instance.

``` ruby
def log_trial(trial)
  logger.info "experiment=%s alternative=%s user=%s" %
    [ trial.experiment.name, trial.alternative, current_user.id ]
end

def log_trial_choose(trial)
  logger.info "[new user] experiment=%s alternative=%s user=%s" %
    [ trial.experiment.name, trial.alternative, current_user.id ]
end

def log_trial_complete(trial)
  logger.info "experiment=%s alternative=%s user=%s complete=true" %
    [ trial.experiment.name, trial.alternative, current_user.id ]
end
```

#### Views

If you are running `ab_test` from a view, you must define your event
hook callback as a
[helper_method](https://apidock.com/rails/AbstractController/Helpers/ClassMethods/helper_method)
in the controller:

``` ruby
helper_method :log_trial_choose

def log_trial_choose(trial)
  logger.info "experiment=%s alternative=%s user=%s" %
    [ trial.experiment.name, trial.alternative, current_user.id ]
end
```

### Experiment Hooks

You can assign a proc that will be called when an experiment is reset or deleted. You can use these hooks to call methods within your application to keep data related to experiments in sync with Split.

For example:

``` ruby
Split.configure do |config|
  # after experiment reset or deleted
  config.on_experiment_reset  = -> (example) { # Do something on reset }
  config.on_experiment_delete = -> (experiment) { # Do something else on delete }
  # before experiment reset or deleted
  config.on_before_experiment_reset  = -> (example) { # Do something on reset }
  config.on_before_experiment_delete = -> (experiment) { # Do something else on delete }
end
```

## Web Interface

Split comes with a Sinatra-based front end to get an overview of how your experiments are doing.

If you are running Rails 2: You can mount this inside your app using Rack::URLMap in your `config.ru`

```ruby
require 'split/dashboard'

run Rack::URLMap.new \
  "/"       => Your::App.new,
  "/split" => Split::Dashboard.new
```

However, if you are using Rails 3 or higher: You can mount this inside your app routes by first adding this to the Gemfile:

```ruby
gem 'split', require: 'split/dashboard'
```

Then adding this to config/routes.rb

```ruby
mount Split::Dashboard, at: 'split'
```

You may want to password protect that page, you can do so with `Rack::Auth::Basic` (in your split initializer file)

```ruby
# Rails apps or apps that already depend on activesupport
Split::Dashboard.use Rack::Auth::Basic do |username, password|
  # Protect against timing attacks:
  # - Use & (do not use &&) so that it doesn't short circuit.
  # - Use digests to stop length information leaking
  ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SPLIT_USERNAME"])) &
    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SPLIT_PASSWORD"]))
end

# Apps without activesupport
Split::Dashboard.use Rack::Auth::Basic do |username, password|
  # Protect against timing attacks:
  # - Use & (do not use &&) so that it doesn't short circuit.
  # - Use digests to stop length information leaking
  Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SPLIT_USERNAME"])) &
    Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SPLIT_PASSWORD"]))
end
```

You can even use Devise or any other Warden-based authentication method to authorize users. Just replace `mount Split::Dashboard, :at => 'split'` in `config/routes.rb` with the following:
```ruby
match "/split" => Split::Dashboard, anchor: false, via: [:get, :post, :delete], constraints: -> (request) do
  request.env['warden'].authenticated? # are we authenticated?
  request.env['warden'].authenticate! # authenticate if not already
  # or even check any other condition such as request.env['warden'].user.is_admin?
end
```

More information on this [here](https://steve.dynedge.co.uk/2011/12/09/controlling-access-to-routes-and-rack-apps-in-rails-3-with-devise-and-warden/)

### Screenshot

![split_screenshot](https://raw.githubusercontent.com/caser/caser.github.io/master/dashboard.png)

## Configuration

You can override the default configuration options of Split like so:

```ruby
Split.configure do |config|
  config.db_failover = true # handle Redis errors gracefully
  config.db_failover_on_db_error = -> (error) { Rails.logger.error(error.message) }
  config.allow_multiple_experiments = true
  config.enabled = true
  config.persistence = Split::Persistence::SessionAdapter
  #config.start_manually = false ## new test will have to be started manually from the admin panel. default false
  #config.reset_manually = false ## if true, it never resets the experiment data, even if the configuration changes
  config.include_rails_helper = true
  config.redis = "redis://custom.redis.url:6380"
end
```

Split looks for the Redis host in the environment variable `REDIS_URL` then
defaults to `redis://localhost:6379` if not specified by configure block.

On platforms like Heroku, Split will use the value of `REDIS_PROVIDER` to
determine which env variable key to use when retrieving the host config. This
defaults to `REDIS_URL`.

### Filtering

In most scenarios you don't want to have AB-Testing enabled for web spiders, robots or special groups of users.
Split provides functionality to filter this based on a predefined, extensible list of bots, IP-lists or custom exclude logic.

```ruby
Split.configure do |config|
  # bot config
  config.robot_regex = /my_custom_robot_regex/ # or
  config.bots['newbot'] = "Description for bot with 'newbot' user agent, which will be added to config.robot_regex for exclusion"

  # IP config
  config.ignore_ip_addresses << '81.19.48.130' # or regex: /81\.19\.48\.[0-9]+/

  # or provide your own filter functionality, the default is proc{ |request| is_robot? || is_ignored_ip_address? || is_preview? }
  config.ignore_filter = -> (request) { CustomExcludeLogic.excludes?(request) }
end
```

### Experiment configuration

Instead of providing the experiment options inline, you can store them
in a hash. This hash can control your experiment's alternatives, weights,
algorithm and if the experiment resets once finished:

```ruby
Split.configure do |config|
  config.experiments = {
    my_first_experiment: {
      alternatives: ["a", "b"],
      resettable: false
    },
    :my_second_experiment => {
      algorithm: 'Split::Algorithms::Whiplash',
      alternatives: [
        { name: "a", percent: 67 },
        { name: "b", percent: 33 }
      ]
    }
  }
end
```

You can also store your experiments in a YAML file:

```ruby
Split.configure do |config|
  config.experiments = YAML.load_file "config/experiments.yml"
end
```

You can then define the YAML file like:

```yaml
my_first_experiment:
  alternatives:
    - a
    - b
my_second_experiment:
  alternatives:
    - name: a
      percent: 67
    - name: b
      percent: 33
  resettable: false
```

This simplifies the calls from your code:

```ruby
ab_test(:my_first_experiment)
```

and:

```ruby
ab_finished(:my_first_experiment)
```

You can also add meta data for each experiment, which is very useful when you need more than an alternative name to change behaviour:

```ruby
Split.configure do |config|
  config.experiments = {
    my_first_experiment: {
      alternatives: ["a", "b"],
      metadata: {
        "a" => {"text" => "Have a fantastic day"},
        "b" => {"text" => "Don't get hit by a bus"}
      }
    }
  }
end
```

```yaml
my_first_experiment:
  alternatives:
    - a
    - b
  metadata:
    a:
      text: "Have a fantastic day"
    b:
      text: "Don't get hit by a bus"
```

This allows for some advanced experiment configuration using methods like:

```ruby
trial.alternative.name # => "a"

trial.metadata['text'] # => "Have a fantastic day"
```

or in views:

```erb
<% ab_test("my_first_experiment") do |alternative, meta| %>
  <%= alternative %>
  <small><%= meta['text'] %></small>
<% end %>
```

The keys used in meta data should be Strings

#### Metrics

You might wish to track generic metrics, such as conversions, and use
those to complete multiple different experiments without adding more to
your code. You can use the configuration hash to do this, thanks to
the `:metric` option.

```ruby
Split.configure do |config|
  config.experiments = {
    my_first_experiment: {
      alternatives: ["a", "b"],
      metric: :my_metric
    }
  }
end
```

Your code may then track a completion using the metric instead of
the experiment name:

```ruby
ab_finished(:my_metric)
```

You can also create a new metric by instantiating and saving a new Metric object.

```ruby
Split::Metric.new(:my_metric)
Split::Metric.save
```

#### Goals

You might wish to allow an experiment to have multiple, distinguishable goals.
The API to define goals for an experiment is this:

```ruby
ab_test({link_color: ["purchase", "refund"]}, "red", "blue")
```

or you can you can define them in a configuration file:

```ruby
Split.configure do |config|
  config.experiments = {
    link_color: {
      alternatives: ["red", "blue"],
      goals: ["purchase", "refund"]
    }
  }
end
```

To complete a goal conversion, you do it like:

```ruby
ab_finished(link_color: "purchase")
```

Note that if you pass additional options, that should be a separate hash:

```ruby
ab_finished({ link_color: "purchase" }, reset: false)
```

**NOTE:** This does not mean that a single experiment can complete more than one goal.

Once you finish one of the goals, the test is considered to be completed, and finishing the other goal will no longer register. (Assuming the test runs with `reset: false`.)

**Good Example**: Test if listing Plan A first result in more conversions to Plan A (goal: "plana_conversion") or Plan B (goal: "planb_conversion").

**Bad Example**: Test if button color increases conversion rate through multiple steps of a funnel. THIS WILL NOT WORK.

**Bad Example**: Test both how button color affects signup *and* how it affects login, at the same time. THIS WILL NOT WORK.

#### Combined Experiments
If you want to test how button color affects signup *and* how it affects login at the same time, use combined experiments.
Configure like so:
```ruby
  Split.configuration.experiments = {
        :button_color_experiment => {
          :alternatives => ["blue", "green"],
          :combined_experiments => ["button_color_on_signup", "button_color_on_login"]
        }
      }
```

Starting the combined test starts all combined experiments
```ruby
 ab_combined_test(:button_color_experiment)
```
Finish each combined test as normal

```ruby
   ab_finished(:button_color_on_login)
   ab_finished(:button_color_on_signup)
```

**Additional Configuration**:
* Be sure to enable `allow_multiple_experiments`
* In Sinatra include the CombinedExperimentsHelper
  ```
    helpers Split::CombinedExperimentsHelper
  ```
### DB failover solution

Due to the fact that Redis has no automatic failover mechanism, it's
possible to switch on the `db_failover` config option, so that `ab_test`
and `ab_finished` will not crash in case of a db failure. `ab_test` always
delivers alternative A (the first one) in that case.

It's also possible to set a `db_failover_on_db_error` callback (proc)
for example to log these errors via Rails.logger.

### Redis

You may want to change the Redis host and port Split connects to, or
set various other options at startup.

Split has a `redis` setter which can be given a string or a Redis
object. This means if you're already using Redis in your app, Split
can re-use the existing connection.

String: `Split.redis = 'redis://localhost:6379'`

Redis: `Split.redis = $redis`

For our rails app we have a `config/initializers/split.rb` file where
we load `config/split.yml` by hand and set the Redis information
appropriately.

Here's our `config/split.yml`:

```yml
development: redis://localhost:6379
test: redis://localhost:6379
staging: redis://redis1.example.com:6379
fi: redis://localhost:6379
production: redis://redis1.example.com:6379
```

And our initializer:

```ruby
split_config = YAML.load_file(Rails.root.join('config', 'split.yml'))
Split.redis = split_config[Rails.env]
```

## Namespaces

If you're running multiple, separate instances of Split you may want
to namespace the keyspaces so they do not overlap. This is not unlike
the approach taken by many memcached clients.

This feature can be provided by the [redis-namespace](https://github.com/defunkt/redis-namespace)
library. To configure Split to use `Redis::Namespace`, do the following:

1. Add `redis-namespace` to your Gemfile:

  ```ruby
  gem 'redis-namespace'
  ```

2. Configure `Split.redis` to use a `Redis::Namespace` instance (possible in an
   intializer):

  ```ruby
  redis = Redis.new(url: ENV['REDIS_URL']) # or whatever config you want
  Split.redis = Redis::Namespace.new(:your_namespace, redis: redis)
  ```

## Outside of a Web Session

Split provides the Helper module to facilitate running experiments inside web sessions.

Alternatively, you can access the underlying Metric, Trial, Experiment and Alternative objects to
conduct experiments that are not tied to a web session.

```ruby
# create a new experiment
experiment = Split::ExperimentCatalog.find_or_create('color', 'red', 'blue')
# create a new trial
trial = Split::Trial.new(:experiment => experiment)
# run trial
trial.choose!
# get the result, returns either red or blue
trial.alternative.name

# if the goal has been achieved, increment the successful completions for this alternative.
if goal_achieved?
  trial.complete!
end

```

## Algorithms

By default, Split ships with `Split::Algorithms::WeightedSample` that randomly selects from possible alternatives for a traditional a/b test.
It is possible to specify static weights to favor certain alternatives.

`Split::Algorithms::Whiplash` is an implementation of a [multi-armed bandit algorithm](http://stevehanov.ca/blog/index.php?id=132).
This algorithm will automatically weight the alternatives based on their relative performance,
choosing the better-performing ones more often as trials are completed.

`Split::Algorithms::BlockRandomization` is an algorithm that ensures equal
participation across all alternatives. This algorithm will choose the alternative
with the fewest participants. In the event of multiple minimum participant alternatives
(i.e. starting a new "Block") the algorithm will choose a random alternative from
those minimum participant alternatives.

Users may also write their own algorithms. The default algorithm may be specified globally in the configuration file, or on a per experiment basis using the experiments hash of the configuration file.

To change the algorithm globally for all experiments, use the following in your initializer:

```ruby
Split.configure do |config|
  config.algorithm = Split::Algorithms::Whiplash
end
```

## Extensions

  - [Split::Export](https://github.com/splitrb/split-export) - Easily export A/B test data out of Split.
  - [Split::Analytics](https://github.com/splitrb/split-analytics) - Push test data to Google Analytics.
  - [Split::Mongoid](https://github.com/MongoHQ/split-mongoid) - Store experiment data in mongoid (still uses redis).
  - [Split::Cacheable](https://github.com/harrystech/split_cacheable) - Automatically create cache buckets per test.
  - [Split::Counters](https://github.com/bernardkroes/split-counters) - Add counters per experiment and alternative.
  - [Split::Cli](https://github.com/craigmcnamara/split-cli) - A CLI to trigger Split A/B tests.

## Screencast

Ryan bates has produced an excellent 10 minute screencast about split on the Railscasts site: [A/B Testing with Split](http://railscasts.com/episodes/331-a-b-testing-with-split)

## Blogposts

* [Recipe: A/B testing with KISSMetrics and the split gem](https://robots.thoughtbot.com/post/9595887299/recipe-a-b-testing-with-kissmetrics-and-the-split-gem)
* [Rails A/B testing with Split on Heroku](http://blog.nathanhumbert.com/2012/02/rails-ab-testing-with-split-on-heroku.html)

## Backers

Support us with a monthly donation and help us continue our activities. [[Become a backer](https://opencollective.com/split#backer)]

<a href="https://opencollective.com/split/backer/0/website" target="_blank"><img src="https://opencollective.com/split/backer/0/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/1/website" target="_blank"><img src="https://opencollective.com/split/backer/1/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/2/website" target="_blank"><img src="https://opencollective.com/split/backer/2/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/3/website" target="_blank"><img src="https://opencollective.com/split/backer/3/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/4/website" target="_blank"><img src="https://opencollective.com/split/backer/4/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/5/website" target="_blank"><img src="https://opencollective.com/split/backer/5/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/6/website" target="_blank"><img src="https://opencollective.com/split/backer/6/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/7/website" target="_blank"><img src="https://opencollective.com/split/backer/7/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/8/website" target="_blank"><img src="https://opencollective.com/split/backer/8/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/9/website" target="_blank"><img src="https://opencollective.com/split/backer/9/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/10/website" target="_blank"><img src="https://opencollective.com/split/backer/10/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/11/website" target="_blank"><img src="https://opencollective.com/split/backer/11/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/12/website" target="_blank"><img src="https://opencollective.com/split/backer/12/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/13/website" target="_blank"><img src="https://opencollective.com/split/backer/13/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/14/website" target="_blank"><img src="https://opencollective.com/split/backer/14/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/15/website" target="_blank"><img src="https://opencollective.com/split/backer/15/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/16/website" target="_blank"><img src="https://opencollective.com/split/backer/16/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/17/website" target="_blank"><img src="https://opencollective.com/split/backer/17/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/18/website" target="_blank"><img src="https://opencollective.com/split/backer/18/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/19/website" target="_blank"><img src="https://opencollective.com/split/backer/19/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/20/website" target="_blank"><img src="https://opencollective.com/split/backer/20/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/21/website" target="_blank"><img src="https://opencollective.com/split/backer/21/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/22/website" target="_blank"><img src="https://opencollective.com/split/backer/22/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/23/website" target="_blank"><img src="https://opencollective.com/split/backer/23/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/24/website" target="_blank"><img src="https://opencollective.com/split/backer/24/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/25/website" target="_blank"><img src="https://opencollective.com/split/backer/25/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/26/website" target="_blank"><img src="https://opencollective.com/split/backer/26/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/27/website" target="_blank"><img src="https://opencollective.com/split/backer/27/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/28/website" target="_blank"><img src="https://opencollective.com/split/backer/28/avatar.svg"></a>
<a href="https://opencollective.com/split/backer/29/website" target="_blank"><img src="https://opencollective.com/split/backer/29/avatar.svg"></a>


## Sponsors

Become a sponsor and get your logo on our README on Github with a link to your site. [[Become a sponsor](https://opencollective.com/split#sponsor)]

<a href="https://opencollective.com/split/sponsor/0/website" target="_blank"><img src="https://opencollective.com/split/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/1/website" target="_blank"><img src="https://opencollective.com/split/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/2/website" target="_blank"><img src="https://opencollective.com/split/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/3/website" target="_blank"><img src="https://opencollective.com/split/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/4/website" target="_blank"><img src="https://opencollective.com/split/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/5/website" target="_blank"><img src="https://opencollective.com/split/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/6/website" target="_blank"><img src="https://opencollective.com/split/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/7/website" target="_blank"><img src="https://opencollective.com/split/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/8/website" target="_blank"><img src="https://opencollective.com/split/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/9/website" target="_blank"><img src="https://opencollective.com/split/sponsor/9/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/10/website" target="_blank"><img src="https://opencollective.com/split/sponsor/10/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/11/website" target="_blank"><img src="https://opencollective.com/split/sponsor/11/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/12/website" target="_blank"><img src="https://opencollective.com/split/sponsor/12/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/13/website" target="_blank"><img src="https://opencollective.com/split/sponsor/13/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/14/website" target="_blank"><img src="https://opencollective.com/split/sponsor/14/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/15/website" target="_blank"><img src="https://opencollective.com/split/sponsor/15/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/16/website" target="_blank"><img src="https://opencollective.com/split/sponsor/16/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/17/website" target="_blank"><img src="https://opencollective.com/split/sponsor/17/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/18/website" target="_blank"><img src="https://opencollective.com/split/sponsor/18/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/19/website" target="_blank"><img src="https://opencollective.com/split/sponsor/19/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/20/website" target="_blank"><img src="https://opencollective.com/split/sponsor/20/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/21/website" target="_blank"><img src="https://opencollective.com/split/sponsor/21/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/22/website" target="_blank"><img src="https://opencollective.com/split/sponsor/22/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/23/website" target="_blank"><img src="https://opencollective.com/split/sponsor/23/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/24/website" target="_blank"><img src="https://opencollective.com/split/sponsor/24/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/25/website" target="_blank"><img src="https://opencollective.com/split/sponsor/25/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/26/website" target="_blank"><img src="https://opencollective.com/split/sponsor/26/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/27/website" target="_blank"><img src="https://opencollective.com/split/sponsor/27/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/28/website" target="_blank"><img src="https://opencollective.com/split/sponsor/28/avatar.svg"></a>
<a href="https://opencollective.com/split/sponsor/29/website" target="_blank"><img src="https://opencollective.com/split/sponsor/29/avatar.svg"></a>

## Contribute

Please do! Over 70 different people have contributed to the project, you can see them all here: https://github.com/splitrb/split/graphs/contributors.

### Development

The source code is hosted at [GitHub](https://github.com/splitrb/split).

Report issues and feature requests on [GitHub Issues](https://github.com/splitrb/split/issues).

You can find a discussion form on [Google Groups](https://groups.google.com/d/forum/split-ruby).

### Tests

Run the tests like this:

    # Start a Redis server in another tab.
    redis-server

    bundle
    rake spec

### A Note on Patches and Pull Requests

 * Fork the project.
 * Make your feature addition or bug fix.
 * Add tests for it. This is important so I don't break it in a
   future version unintentionally.
 * Add documentation if necessary.
 * Commit. Do not mess with the rakefile, version, or history.
   (If you want to have your own version, that is fine. But bump the version in a commit by itself, which I can ignore when I pull.)
 * Send a pull request. Bonus points for topic branches.

### Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

## Copyright

[MIT License](LICENSE) © 2019 [Andrew Nesbitt](https://github.com/andrew).
