function confirmReset() {
  var agree = confirm("This will delete all data for this experiment?");
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
  var agree = confirm("This will enable the cohorting of the experiment. Note: New partcipants who engage will be given the control (not recorded). Are you sure?");
  return agree ? true : false;
}

function confirmDisableCohorting(){
  var agree = confirm("This will disable the cohorting of the experiment. Note: Existing partcipants will continue to receive their alternative and may continue to convert. Are you sure?");
  return agree ? true : false;
}
