# embedded-i18n-actions
This library exposes custom Github Actions to integrate with Gusto Embedded's i18n translation vendors.

## Usage
### Push sources action
This action pushes to Lokalise the English source files found in the list of `locale_paths` of your repository. It requires the following inputs:
- `lokalise_project_id`: Your Lokalise project ID (can be found in your Lokalise project settings). This must be stored as a Github variable in your repository settings.
- `lokalise_api_token`: The Lokalise API token used to authenticate with Lokalise. This must be stored as a Github secret in your repository settings.
- `locale_paths`: The list of paths that will be used to search for locale files (default: [config/locales])

And accepts the following optional inputs:
- `file_patterns`: The file names of your english sources in the `config/locales` directory. Defaults to `'**en.yml **en.json'`.

To use this action in your repository, set up a Github Action [workflow](https://docs.github.com/en/actions/writing-workflows/about-workflows#about-workflows) in your `.github/workflows` directory similar to the following YAML:

```
name: Push Sources

on:
  workflow_dispatch:

jobs:
  push-sources:
    runs-on: ubuntu-latest
    steps:
      - name: Push sources
        uses: Gusto/embedded-i18n-actions/.github/actions/push_sources@v1.0.0
        with:
          lokalise_project_id: ${{ vars.LOKALISE_PROJECT_ID }}
          lokalise_api_token: ${{ secrets.LOKALISE_API_TOKEN }}
          locale_paths: |
            config/locales/en
            config/locales/awesome/module
```

### Pull translations action
This action pulls new, reviewed translations from Lokalise and creates a PR with the translation changes for your repo. It requires the following inputs:
- `lokalise_project_id`: Your Lokalise project ID (can be found in your Lokalise project settings). This can be stored as a Github variable in your repository settings.
- `github_token`: The Github token used to authenticate with Github and create the translation changes PR. This should already be available through `secrets.GITHUB_TOKEN` in your repo.
- `lokalise_api_token`: The Lokalise API token used to authenticate with Lokalise. This should be stored as a Github secret in your repository settings.

To use this action in your repository, set up a Github Action [workflow](https://docs.github.com/en/actions/writing-workflows/about-workflows#about-workflows) in your `.github/workflows` directory similar to the following YAML:
```
name: Pull Translations

on:
  workflow_dispatch:

jobs:
  pull-translations:
    runs-on: ubuntu-latest
    steps:
      - name: Pull translations
        uses: Gusto/embedded-i18n-actions/.github/actions/pull_translations@v1.0.0
        with:
          lokalise_project_id: ${{ vars.LOKALISE_PROJECT_ID }}
          lokalise_api_token: ${{ secrets.LOKALISE_API_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

## Development

### Current vendors supported:
- [Lokalise](https://lokalise.com/)

### Current vendor actions supported:
- [Push sources](https://github.com/marketplace/actions/push-to-lokalise) to Lokalise
- [Pull translations](https://github.com/marketplace/actions/pull-from-lokalise) from Lokalise

Note that any new third-party actions must be approved by Security and added to the allow list. Please reach out to Security to consume any new actions.
