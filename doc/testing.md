# Testing

From the repository root:

```sh
dart pub get
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

CI checks that tests cover at least 80% of the lines in the library.
To inspect a report locally, install LCOV and run
`genhtml coverage/lcov.info --output-directory coverage/html`.
Open `coverage/html/index.html` in your browser.
