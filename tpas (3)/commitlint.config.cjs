/* eslint-disable no-undef */
module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "header-max-length": [2, "always", 100],
    "type-enum": [
      2,
      "always",
      [
        "fix",
        "feat",
        "docs",
        "style",
        "refactor",
        "perf",
        "test",
        "chore",
        "build",
        "ci",
        "revert",
        "remove",
        "hotfix",
        "release",

        //
      ],
    ],
    "scope-enum": [1, "always", ["api1", "api2", "db", "ui", "core"]],
    "subject-empty": [2, "never"],
  },
};
