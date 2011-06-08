function confirmReset() {
  var agree=confirm("This will delete all data for this experiment?");
  if (agree)
    return true;
  else
    return false;
}

function confirmWinner() {
  var agree=confirm("This will now be returned for all users. Are you sure?");
  if (agree)
    return true;
  else
    return false;
}