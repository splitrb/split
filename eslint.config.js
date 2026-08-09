const js = require("@eslint/js");
const globals = require("globals");

module.exports = [
  { ignores: ["coverage/"] },
  js.configs.recommended,
  {
    files: ["lib/**/*.js"],
    languageOptions: {
      globals: globals.browser
    },
    rules: {
      "no-empty": ["error", { allowEmptyCatch: true }]
    }
  },
  {
    files: ["eslint.config.js"],
    languageOptions: {
      globals: globals.node
    }
  }
];
