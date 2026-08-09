(function () {
  "use strict";

  function setVisibility(elements, visible) {
    elements.forEach(function (element) {
      element.style.display = visible ? "" : "none";
    });
  }

  function bindNameFilter() {
    var filterInput = document.getElementById("filter");
    if (!filterInput) return;

    filterInput.addEventListener("keyup", function () {
      var query = filterInput.value.toLowerCase();
      document.querySelectorAll("div.experiment").forEach(function (experiment) {
        var name = (experiment.dataset.name || "").toLowerCase();
        experiment.style.display = name.indexOf(query) === -1 ? "none" : "";
      });
    });
  }

  function bindFilterReset() {
    var clearButton = document.getElementById("clear-filter");
    var filterInput = document.getElementById("filter");
    if (!clearButton || !filterInput) return;

    clearButton.addEventListener("click", function () {
      filterInput.value = "";
      setVisibility(document.querySelectorAll("div.experiment"), true);
      document.querySelectorAll("#toggle-active, #toggle-completed").forEach(function (toggle) {
        toggle.value = toggle.value.replace("Show", "Hide");
      });
    });
  }

  function bindCompletionToggle(buttonId, completeState) {
    var button = document.getElementById(buttonId);
    if (!button) return;

    button.addEventListener("click", function () {
      var hiding = button.value.indexOf("Hide") === 0;
      button.value = hiding
        ? button.value.replace("Hide", "Show")
        : button.value.replace("Show", "Hide");

      setVisibility(
        document.querySelectorAll('div.experiment[data-complete="' + completeState + '"]'),
        !hiding
      );
    });
  }

  function bindConfidenceToggles() {
    document.querySelectorAll('select[id^="dropdown-"]').forEach(function (dropdown) {
      var experimentKey = dropdown.id.slice("dropdown-".length);

      setVisibility(document.querySelectorAll(".probability-" + experimentKey), false);

      dropdown.addEventListener("change", function () {
        setVisibility(document.querySelectorAll(".box-" + experimentKey), false);
        setVisibility(document.querySelectorAll("." + dropdown.value), true);
      });
    });
  }

  function bindThemeToggle() {
    var button = document.getElementById("theme-toggle");
    if (!button) return;

    function activeTheme() {
      var selected = document.documentElement.getAttribute("data-theme");
      if (selected) return selected;
      return window.matchMedia &&
        window.matchMedia("(prefers-color-scheme: dark)").matches
        ? "dark"
        : "light";
    }

    function refreshButtonLabel() {
      button.textContent = activeTheme() === "dark" ? "☀ Light" : "☾ Dark";
    }

    refreshButtonLabel();

    button.addEventListener("click", function () {
      var nextTheme = activeTheme() === "dark" ? "light" : "dark";
      document.documentElement.setAttribute("data-theme", nextTheme);
      try {
        localStorage.setItem("split-theme", nextTheme);
      } catch {}
      refreshButtonLabel();
    });
  }

  function bindConfirmDialogs() {
    document.addEventListener("submit", function (event) {
      var message = event.target.getAttribute("data-confirm");
      if (message && !window.confirm(message)) event.preventDefault();
    });
  }

  bindNameFilter();
  bindFilterReset();
  bindCompletionToggle("toggle-active", "false");
  bindCompletionToggle("toggle-completed", "true");
  bindConfidenceToggles();
  bindThemeToggle();
  bindConfirmDialogs();
})();
