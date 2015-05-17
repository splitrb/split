## 1.2.1 (May 17th, 2015)

Features

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

Features

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

Misc

  - Internal code tidy up (@IanVaughan, #238)

## 0.7.0 (December 26th, 2013)

Features:

  - Significantly improved z-score algorithm (@caser ,#221)
  - Better sorting of Experiments on dashboard (@wadako111, #218)

Bugfixes:

  - Fixed start button not being displayed in some cases (@vigosan, #219)

Misc

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
