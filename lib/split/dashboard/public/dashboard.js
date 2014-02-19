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

function confirmResetCounter() {
  var agree = confirm("This will reset the value for this counter, experiment and alternative?");
  return agree ? true : false;
}

function confirmDeleteCounter() {
  var agree = confirm("Are you sure you want to delete this counter and all its data?");
  return agree ? true : false;
}


