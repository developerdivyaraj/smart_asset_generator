## 0.2.1

- **GitLab Token Fallback**: The PR checker script now properly falls back to `CI_JOB_TOKEN` if `GITLAB_TOKEN` is not specified, preventing `401 Unauthorized` errors when posting comments to Merge Requests.
- **Configurable Email Notifications**: Added `emails` parameter to the `prchecker` command (e.g. `dart run smart_asset_generator prchecker emails="dev@company.com"`) to define recipients inside the generated Python script securely.

## 0.2.0

- **PR Checker Redesign**: Introduced a Stakeholder-Friendly Quality Dashboard with Health Scores, Executive Summaries, and categorized business impacts (Security, Architecture, Quality).
- **Secure Email Management**: Moved recipient configuration to GitLab CI/CD environment variables for centralized PM control and better security.
- **Gmail App Password Support**: Improved SMTP reliability and added comprehensive documentation for setting up App Passwords.
- **Smart Recipient Detection**: Integrated logic to prioritize environment-driven email lists over generated fallbacks.
- **Dashboard UI Enhancements**: Added expandable technical details for developers while keeping the main report clean for managers and clients.
- **Improved Scaffolding**: Refined `.gitlab-ci.yml` automatic configuration for better pipeline integration.

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
