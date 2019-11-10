## 3.4.0 (November 9th, 2019)

Features:
- Improve DualAdapter (@santib, #588), adds a new configuration for the DualAdapter, making it possible to keep consistency for logged_out/logged_in users. It's a opt-in flag. No Behavior was changed on this release.
- Make dashboard pagination default "per" param configurable (@alopatin, #597)

Bugfixes:
- Fix `force_alternative` for experiments with incremented version (@giraffate, #568)
- Persist alternative weights (@giraffate, #570)
- Combined experiment performance improvements (@gnanou, #575)
- Handle correctly case when ab_finished is called before ab_test for a user (@gnanou, #577)
- When loading active_experiments, it should not look into user's 'finished' keys (@andrehjr, #582)

Misc:
- Remove `rubyforge_project` from gemspec (@giraffate, #583)
- Fix URLs to replace http with https (@giraffate , #584)
- Lazily include split helpers in ActionController::Base (@hasghari, #586)
- Fix unused variable warnings (@andrehjr, #592)
- Fix ruby warnings (@andrehjr, #593)
- Update rubocop.yml config (@andrehjr, #594)
- Add frozen_string_literal to all files that were missing it (@andrehjr, #595)

## 3.3.2 (April 12th, 2019)

Features:
- Added uptime robot to configuration.rb (@razel1982, #556)
- Check to see if being run in Rails application and run in before_initialize (@husteadrobert, #555)

Bugfixes:
- Fix error message interpolation (@hanibash, #553)
- Fix Bigdecimal warnings (@agraves, #551)
- Avoid hitting up on redis for robots/excluded users. (@andrehjr, #544)
- Checks for defined?(request) on Helper#exclude_visitor?. (@andrehjr)

Misc:
- Update travis to add Rails 6 (@edmilton, #559)
- Fix broken specs in developement environment (@dougpetronilio, #557)

## 3.3.1 (January 11th, 2019)

Features:
- Filter some more bots (@janosch-x, #542)

Bugfixes:
- Fix Dashboard Pagination Helper typo (@cattekin, #541)
- Do not storage alternative in cookie if experiment has a winner (@sadhu89, #539)
- fix user participating alternative not found (@NaturalHokke, #536)

Misc:
- Tweak RSpec instructions (@eliotsykes, #540)
- Improve README regarding rspec usage (@vermaxik, #538)

## 3.3.0 (August 13th, 2018)

Features:

- Added pagination for dashboard (@GeorgeGorbanev, #518)
- Add Facebot crawler to list of bots (@pfeiffer, #530)
- Ignore previewing requests (@pfeiffer, #531)
- Fix binding of ignore_filter (@pfeiffer, #533)

Bugfixes:

- Fix cookie header duplication (@andrehjr, #522)

Performance:

- Improve performance of RedisInterface#make_list_length by using LTRIM command (@mlovic, #509)

Misc:

- Update development dependencies
- test rails 5.2 on travis (@lostapathy, #524)
- update ruby versions for travis (@lostapathy, #525)

## 3.2.0 (September 21st, 2017)

Features:

- Allow configuration of how often winning alternatives are recalculated (@patbl, #501)

Bugfixes:

- Avoid z_score numeric exception for conversion rates >1 (@cmantas, #503)
- Fix combined experiments (@semanticart, #502)

## 3.1.1 (August 30th, 2017)

Bugfixes:

- Bring back support for ruby 1.9.3 and greater (rubygems 2.0.0 or greater now required) (@patbl, #498)

Misc:

- Document testing with RSpec (@eliotsykes, #495)

## 3.1.0 (August 14th, 2017)

Features:

- Support for combined experiments (@daviddening, #493)
- Rewrite CookieAdapter to work with Rack::Request and Rack::Response directly (@andrehjr, #490)
- Enumeration of a User's Experiments that Respects the db_failover Option(@MarkRoddy, #487)

Bugfixes:

- Blocked a few more common bot user agents (@kylerippey, #485)

Misc:

- Repository Audit by Maintainer.io (@RichardLitt, #484)
- Update development dependencies
- Test on ruby 2.4.1
- Test compatibility with rails 5.1
- Add uris to metadata section in gemspec

## 3.0.0 (March 30th, 2017)

Features:

- added block randomization algorithm and specs (@hulleywood, #475)
- Add ab_record_extra_info to allow record extra info to alternative and display on dashboard. (@tranngocsam, #460)

Bugfixes:

- Avoid crashing on Ruby 2.4 for numeric strings (@flori, #470)
- Fix issue where redis isn't required (@tomciopp , #466)

Misc:

- Avoid variable_size_secure_compare private method (@eliotsykes, #465)

## 2.2.0 (November 11th, 2016)

**Backwards incompatible!** Redis keys are renamed. Please make sure all running tests are completed before you upgrade, as they will reset.

Features:

- Remove dependency on Redis::Namespace (@bschaeffer, #425)
- Make resetting on experiment change optional (@moggyboy, #430)
- Add ability to force alternative on dashboard (@ccallebs, #437)

Bugfixes:

- Fix variations reset across page loads for multiple=control and improve coverage (@Vasfed, #432)

Misc:

- Remove Explicit Return (@BradHudson, #441)
- Update Redis config docs (@bschaeffer, #422)
- Harden HTTP Basic snippet against timing attacks (@eliotsykes, #443)
- Removed a couple old ruby 1.8 hacks (@andrew, #456)
- Run tests on rails 5 (@andrew, #457)
- Fixed a few codeclimate warnings (@andrew, #458)
- Use codeclimate for test coverage (@andrew #455)

## 2.1.0 (August 8th, 2016)

Features:

- Support REDIS_PROVIDER variable used in Heroku (@kartikluke, #426)

## 2.0.0 (July 17th, 2016)

Breaking changes:

- Removed deprecated `finished` and `begin_experiment` methods
- Namespaced override param to avoid potential clashes (@henrik, #398)

## 1.7.0 (June 28th, 2016)

Features:

- Running concurrent experiments on same endpoint/view (@karmakaze, #421)

## 1.6.0 (June 16th, 2016)

Features:

- Add Dual Redis(logged-in)/cookie(logged-out) persistence adapter (@karmakaze, #420)

## 1.5.0 (June 8th, 2016)

Features:

- Add `expire_seconds:` TTL option to RedisAdapter (@karmakaze, #409)
- Optional custom persistence adapter (@ndelage, #411)

Misc:

- Use fakeredis for testing (@andrew, #412)

## 1.4.5 (June 7th, 2016)

Bugfixes:

- FIX Negative numbers on non-finished (@divineforest, #408)
- Eliminate extra RedisAdapter hget (@karmakaze, #407)
- Remove unecessary code from Experiment class (@pakallis, #391, #392, #393)

Misc:

- Simplify Configuration#normalized_experiments (@pakallis, #395)
- Clarify test running instructions (@henrik, #397)

## 1.4.4 (May 9th, 2016)

Bugfixes:

- Increment participation if store override is true and no experiment key exists (@spheric, #380)

Misc:

- Deprecated `finished` method in favour of `ab_finished` (@andreibondarev, #389)
- Added minimum version requirement to simple-random
- Clarify finished with first option being a hash in Readme (@henrik, #382)
- Refactoring the User abstraction (@andreibondarev, #384)

## 1.4.3 (April 28th, 2016)

Features:

- add on_trial callback whenever a trial is started (@mtyeh411, #375)

Bugfixes:

- Allow algorithm configuration at experiment level (@007sumit, #376)

Misc:

- only choose override if it exists as valid alternative (@spheric, #377)

## 1.4.2 (April 25th, 2016)

Misc:

- Deprecated some legacy methods (@andreibondarev, #374)

## 1.4.1 (April 21st, 2016)

Bugfixes:

- respect manual start configuration after an experiment has been deleted (@mtyeh411, #372)

Misc:

- Introduce goals collection to reduce complexity of Experiment#save (@pakallis, #365)
- Revise specs according to http://betterspecs.org/ (@hkliya, #369)

## 1.4.0 (April 2nd, 2016)

Features:

- Added experiment filters to dashboard (@ccallebs, #363, #364)
- Added Contributor Covenant Code of Conduct

## 1.3.2 (January 2nd, 2016)

Bugfixes:

- Fix deleting experiments in from the updated dashboard (@craigmcnamara, #352)

## 1.3.1 (January 1st, 2016)

Bugfixes:

- Fix the dashboard for experiments with ‘/‘ in the name. (@craigmcnamara, #349)

## 1.3.0 (October 20th, 2015)

Features:

 - allow for custom redis_url different from ENV variable (@davidgrieser, #323)
 - add ability to change the length of the persistence cookie (@peterylai, #335)

Bugfixes:

 - Rescue from Redis::BaseError instead of Redis::CannotConnectError (@nfm, #342)
 - Fix active experiments when experiment is on a later version (@ndrisso, #331)
 - Fix caching of winning alternative (@nfm, #329)

Misc:

 - Remove duplication from Experiment#save (@pakallis, #333)
 - Remove unnecessary argument from Experiment#write_to_alternative (@t4deu, #332)

## 1.2.1 (May 17th, 2015)

Features:

 - Handle redis DNS resolution failures gracefully (@fusion2004, #310)
 - Push metadata to ab_test block (@ekorneeff, #296)
 - Helper methods are now private when included in controllers (@ipoval, #303)

Bugfixes:

 - Return an empty hash as metadata when Split is disabled (@tomasdundacek, #313)
 - Don't use capture helper from ActionView (@tomasdundacek, #312)

Misc:

 - Remove body "max-width" from dashboard (@xicreative, #299)
 - fix private for class methods (@ipoval, #301)
 - minor memoization fix in spec (@ipoval, #304)
 - Minor documentation fixes (#295, #297, #305, #308)

## 1.2.0 (January 24th, 2015)

Features:

  - Configure redis using environment variables if available (@saratovsource , #293)
  - Store metadata on experiment configuration (@dekz, #291)

Bugfixes:

 - Revert the Trial#complete! public API to support noargs (@dekz, #292)

## 1.1.0 (January 9th, 2015)

Changes:

  - Public class methods on `Split::Experiment` (e.g., `find_or_create`)
    have been moved to `Split::ExperimentCatalog`.

Features:

  - Decouple trial from Split::Helper (@joshdover, #286)
  - Helper method for Active Experiments (@blahblahblah-, #273)

Misc:

  - Use the new travis container based infrastructure for tests (@andrew, #280)

## 1.0.0 (October 12th, 2014)

Changes:

  - Remove support for Ruby 1.8.7 and Rails 2.3 (@qpowell, #271)

## 0.8.0 (September 25th, 2014)

Features:

  - Added new way to calculate the probability an alternative is the winner (@caser, #266, #251)
  - support multiple metrics per experiment (@stevenou, #260)

Bugfixes:

  - Avoiding call to params in EncapsulatedHelper (@afn, #257)

## 0.7.3 (September 16th, 2014)

Features:

  - Disable all split tests via a URL parameter (@hwartig, #263)

Bugfixes:

  - Correctly escape experiment names on dashboard (@ecaron, #265)
  - Handle redis connection exception error properly (@andrew, #245)

## 0.7.2 (June 12th, 2014)

Features:

  -  Show metrics on the dashboard (@swrobel, #241)

Bugfixes:

  - Avoid nil error with ExperimentCatalog when upgrading (@danielschwartz, #253)
  - [SECURITY ISSUE] Only allow known alternatives as query param overrides (@ankane, #255)

## 0.7.1 (March 20th, 2014)

Features:

  - You can now reopen experiment from the dashboard (@mikezaby, #235)

Misc:

  - Internal code tidy up (@IanVaughan, #238)

## 0.7.0 (December 26th, 2013)

Features:

  - Significantly improved z-score algorithm (@caser ,#221)
  - Better sorting of Experiments on dashboard (@wadako111, #218)

Bugfixes:

  - Fixed start button not being displayed in some cases (@vigosan, #219)

Misc:

  - Experiment#initialize refactoring (@nberger, #224)
  - Extract ExperimentStore into a seperate class (@nberger, #225)

## 0.6.6 (October 15th, 2013)

Features:

  - Sort experiments on Dashboard so "active" ones without a winner appear first (@swrobel, #204)
  - Starting tests manually (@duksis, #209)

Bugfixes:

  - Only trigger completion callback with valid Trial (@segfaultAX, #208)
  - Fixed bug with `resettable` when using `normalize_experiments` (@jonashuckestein, #213)

Misc:

  - Added more bots to filter list (@lbeder, #214, #215, #216)

## 0.6.5 (August 23, 2013)

Features:

  - Added Redis adapter for persisting experiments across sessions (@fengb, #203)

Misc:

  - Expand upon algorithms section in README (@swrobel, #200)

## 0.6.4 (August 8, 2013)

Features:

  - Add hooks for experiment deletion and resetting (@craigmcnamara, #198)
  - Allow Split::Helper to be used outside of a controller (@nfm, #190)
  - Show current Rails/Rack Env in dashboard (@rceee, #187)

Bugfixes:

  - Fix whiplash algorithm when using goals (@swrobel, #193)

Misc:

  - Refactor dashboard js (@buddhamagnet)

## 0.6.3 (July 8, 2013)

Features:

  - Add hooks for Trial#choose! and Trial#complete! (@bmarini, #176)

Bugfixes:

  - Stores and parses Experiment's start_time as a UNIX integer (@joeroot, #177)

## 0.6.2 (June 6, 2013)

Features:

  - Rails 2.3 compatibility (@bhcarpenter, #167)
  - Adding possibility to store overridden alternative (@duksis, #173)

Misc:

  - Now testing against multiple versions of rails

## 0.6.1 (May 4, 2013)

Bugfixes:

  - Use the specified algorithm for the experiment instead of the default (@woodhull, #165)

Misc:

  - Ensure experiements are valid when configuring (@ashmckenzie, #159)
  - Allow arrays to be passed to ab_test (@fenelon, #156)

## 0.6.0 (April 4, 2013)

Features:

  - Support for Ruby 2.0.0 (@phoet, #142)
  - Multiple Goals (@liujin, #109)
  - Ignoring IPs using Regular Expressions (@waynemoore, #119)
  - Added ability to add more bots to the default list (@themgt, #140)
  - Allow custom configuration of user blocking logic (@phoet , #148)

Bugfixes:

  - Fixed regression in handling of config files (@iangreenleaf, #115)
  - Fixed completion rate increases for experiments users aren't participating in (@philnash, #67)
  - Handle exceptions from invalid JSON in cookies (@iangreenleaf, #126)

Misc:

  - updated minimum json version requirement
  - Refactor Yaml Configuration (@rtwomey, #124)
  - Refactoring of Experiments (@iangreenleaf @tamird, #117 #118)
  - Added more known Bots, including Pingdom, Bing, YandexBot (@julesie, @zinkkrysty, @dimko)
  - Improved Readme (@iangreenleaf @phoet)

## 0.5.0 (January 28, 2013)

Features:

  - Persistence Adapters: Cookies and Session (@patbenatar, #98)
  - Configure experiments from a hash (@iangreenleaf, #97)
  - Pluggable sampling algorithms (@woodhull, #105)

Bugfixes:

  - Fixed negative number of non-finished rates (@philnash, #83)
  - Fixed behaviour of finished(:reset => false) (@philnash, #88)
  - Only take into consideration positive z-scores (@thomasmaas, #96)
  - Amended ab_test method to raise ArgumentError if passed integers or symbols as
    alternatives (@buddhamagnet, #81)

## 0.4.6 (October 28, 2012)

Features:

  - General code quality improvements (@buddhamagnet, #79)

Bugfixes:

  - Don't increment the experiment counter if user has finished (@dimko, #78)
  - Fixed an incorrect test (@jaywengrow, #74)

## 0.4.5 (August 30, 2012)

Bugfixes:

  - Fixed header gradient in FF/Opera (@philnash, #69)
  - Fixed reseting of experiment in session (@apsoto, #43)

## 0.4.4 (August 9, 2012)

Features:

  - Allow parameter overrides, even without Redis. (@bhcarpenter, #62)

Bugfixes:

  - Fixes version number always increasing when alternatives are changed (@philnash, #63)
  - updated guard-rspec to version 1.2

## 0.4.3 (July 8, 2012)

Features:

  - redis failover now recovers from all redis-related exceptions

## 0.4.2 (June 1, 2012)

Features:

  - Now works with v3.0 of redis gem

Bugfixes:

  - Fixed redis failover on Rubinius

## 0.4.1 (April 6, 2012)

Features:

  - Added configuration option to disable Split testing (@ilyakatz, #45)

Bugfixes:

  - Fix weights for existing experiments (@andreas, #40)
  - Fixed dashboard range error (@andrew, #42)

## 0.4.0 (March 7, 2012)

**IMPORTANT**

If using ruby 1.8.x and weighted alternatives you should always pass the control alternative through as the second argument with any other alternatives as a third argument because the order of the hash is not preserved in ruby 1.8, ruby 1.9 users are not affected by this bug.

Features:

  - Experiments now record when they were started (@vrish88, #35)
  - Old versions of experiments in sessions are now cleaned up
  - Avoid users participating in multiple experiments at once (#21)

Bugfixes:

  - Overriding alternatives doesn't work for weighted alternatives (@layflags, #34)
  - confidence_level helper should handle tiny z-scores (#23)

## 0.3.3 (February 16, 2012)

Bugfixes:

  - Fixed redis failover when a block was passed to ab_test (@layflags, #33)

## 0.3.2 (February 12, 2012)

Features:

  - Handle redis errors gracefully (@layflags, #32)

## 0.3.1 (November 19, 2011)

Features:

  - General code tidy up (@ryanlecompte, #22, @mocoso, #28)
  - Lazy loading data from Redis (@lautis, #25)

Bugfixes:

  - Handle unstarted experiments (@mocoso, #27)
  - Relaxed Sinatra version requirement (@martinclu, #24)


## 0.3.0 (October 9, 2011)

Features:

  - Redesigned dashboard (@mrappleton, #17)
  - Use atomic increments in redis for better concurrency (@lautis, #18)
  - Weighted alternatives

Bugfixes:

  - Fix to allow overriding of experiments that aren't on version 1


## 0.2.4 (July 18, 2011)

Features:

  - Added option to finished to not reset the users session

Bugfixes:

  - Only allow strings as alternatives, fixes strange errors when passing true/false or symbols

## 0.2.3 (June 26, 2011)

Features:

  - Experiments can now be deleted from the dashboard
  - ab_test helper now accepts a block
  - Improved dashboard

Bugfixes:

  - After resetting an experiment, existing users of that experiment will also be reset

## 0.2.2 (June 11, 2011)

Features:

  - Updated redis-namespace requirement to 1.0.3
  - Added a configuration object for changing options
  - Robot regex can now be changed via a configuration options
  - Added ability to ignore visits from specified IP addresses
  - Dashboard now shows percentage improvement of alternatives compared to the control
  - If the alternatives of an experiment are changed it resets the experiment and uses the new alternatives

Bugfixes:

  - Saving an experiment multiple times no longer creates duplicate alternatives

## 0.2.1 (May 29, 2011)

Bugfixes:

  - Convert legacy sets to lists to avoid exceptions during upgrades from 0.1.x

## 0.2.0 (May 29, 2011)

Features:

  - Override an alternative via a url parameter
  - Experiments can now be reset from the dashboard
  - The first alternative is now considered the control
  - General dashboard usability improvements
  - Robots are ignored and given the control alternative

Bugfixes:

  - Alternatives are now store in a list rather than a set to ensure consistent ordering
  - Fixed diving by zero errors

## 0.1.1 (May 18, 2011)

Bugfixes:

  - More Robust conversion rate display on dashboard
  - Ensure `Split::Version` is available everywhere, fixed dashboard

## 0.1.0 (May 17, 2011)

Initial Release
