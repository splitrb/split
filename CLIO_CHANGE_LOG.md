1. Added a new field `time_of_assignment` in Redis, and use it to calculate if the user is within the conversion time frame.
2. Added a new field `retain_user_alternatives_after_reset` in YML file, and use it to keep the user's alternative after
the experiment is reset.
3. Updated the `user.rb`'s calculation about `keys_without_experiment` and renamed `keys_without_finished` to 
`experiment_keys`. Because we have our own fields in the Redis, like `time_of_assignment` and `eligibility`, we need to 
exclude them from those functions, in case it breaks Split's behaviour.