# embedded-i18n-actions
This library exposes custom Github Actions to integrate with Gusto Embedded's i18n translation vendors.

## Usage
### Push sources action
This action pushes the english source files defined in the `config/locales` directory of your repository to Lokalise. It requires the following inputs:
- `lokalise_project_id`: Your Lokalise project ID (can be found in your Lokalise project settings). This can be stored as a Github variable in your repository settings.
- `lokalise_api_token`: The Lokalise API token used to authenticate with Lokalise. This should be stored as a Github secret in your repository settings.

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
