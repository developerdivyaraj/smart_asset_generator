## 0.1.0

- Added `prchecker` CLI command that scaffolds `.gitlab/pr_checker.py` from a reusable template.
- Embedded optional GitLab token and project label configuration into the generated checker.
- Automatically maintains `.gitlab-ci.yml`, appending the `mr-check` stage and `pr_checks` job when missing.
- Documented setup steps, CI variables, and command examples in `README.md`.

## 0.0.8

- Expanded CLI with module generator and barrel/asset helpers.
- Improved documentation and developer ergonomics.

## 0.0.1

- Initial release.
