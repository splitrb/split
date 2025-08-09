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


document.addEventListener("DOMContentLoaded", function () {
  const eventHandlers = {
    "split reopen": confirmReopen,
    "split enable-cohorting": confirmEnableCohorting,
    "split disable-cohorting": confirmDisableCohorting,
    "split reset": confirmReset,
    "split delete": confirmDelete,
    "split winner": confirmWinner,
  };

  Object.keys(eventHandlers).forEach(className => {
    const selector = `.${className.replace(" ", ".")}`;
    const elements = document.querySelectorAll(selector);

    if (elements.length > 0) {
      elements.forEach(element => {
        element.addEventListener("click", eventHandlers[className]);
      });
    }
  });
});
