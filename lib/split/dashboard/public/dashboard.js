function confirmReset(retain_user_alternatives_after_reset) {
  warning_message = retain_user_alternatives_after_reset
    ? "This will reset the data for this experiment. Existing users will retain their assigned alternative while not impacting new version metrics. Are you sure?"
    : "This will delete all data for this experiment. Existing users may be recohorted into a new alternative. Are you sure?";

  var agree = confirm(warning_message);
  return agree ? true : false;
}

function confirmDelete() {
  var agree = confirm("Are you sure you want to delete this experiment and all its data?");
  return agree ? true : false;
}

function confirmWinner() {
  var agree = confirm("This will now be returned for all users. Are you sure?");
  return agree ? true : false;
}

function confirmStep(step) {
  var agree = confirm(step);
  return agree ? true : false;
}

function confirmReopen() {
  var agree = confirm("This will reopen the experiment. Are you sure?");
  return agree ? true : false;
}

function confirmEnableCohorting(){
  var agree = confirm("This will enable the cohorting of the experiment. Are you sure?");
  return agree ? true : false;
}

function confirmDisableCohorting(){
  var agree = confirm("This will disable the cohorting of the experiment. Note: Existing participants will continue to receive their alternative and may continue to convert. Are you sure?");
  return agree ? true : false;
}
