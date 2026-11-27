module.exports = {
  extends: ['@commitlint/config-conventional'],
  plugins: [
    {
      rules: {
        'subject-start-case': ({ subject }) => [
          !subject ||
            !/^\p{Lu}/u.test(subject) ||
            subject === subject.toUpperCase(),
          'subject should start with a lowercase letter',
        ],
      },
    },
  ],
  rules: {
    'type-case': [2, 'always', 'lower-case'],
    'scope-case': [2, 'always', 'lower-case'],
    'subject-case': [2, 'never', 'upper-case'],
    'subject-start-case': [1, 'always'],
  },
};
