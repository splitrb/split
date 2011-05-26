function confirmReset() {
  var agree=confirm("This will delete all data for this experiment?");
  if (agree)
    return true;
  else
    return false;
}
