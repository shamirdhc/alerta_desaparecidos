module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2022,
    "sourceType": "module",
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "off",
    "quotes": "off",
    "max-len": "off",
    "object-curly-spacing": "off",
    "require-jsdoc": "off",
    "indent": "off",
    "valid-jsdoc": "off",
    "comma-dangle": "off",
    "no-trailing-spaces": "off",
    "padded-blocks": "off",
    "arrow-parens": "off",
    "prefer-const": "off",
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
