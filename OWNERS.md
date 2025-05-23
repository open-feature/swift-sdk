# Owners

- See [CONTRIBUTING.md](CONTRIBUTING.md) for general contribution guidelines.

## Core Developers

- Fabrizio Demaria (fabriziodemaria, Spotify)
- Mattias Frånberg (mfranberg, Spotify)
- Alina Andersone (alina-v1, Spotify)
- Brian Hackett (Calibretto, Spotify)

## CocoaPods Release Token Management

The automated CocoaPods releases require a valid trunk token that expires every 128 days (~4 months). When the token expires, a core developer needs to update the `COCOAPODS_TRUNK_TOKEN` repository secret.

### Getting a New Token

1. Install CocoaPods if not already installed:
   ```bash
   gem install cocoapods
   ```

2. Register with CocoaPods trunk to generate a new token:
   ```bash
   pod trunk register openfeature-core@groups.io 'OpenFeature' --description='OpenFeature Deployment User'
   ```

3. Check your email and click the verification link (check https://groups.io/g/openfeature-core for the email)

4. Extract the token from your local configuration:
   ```bash
   cat ~/.netrc
   ```
   Look for the `password` field

### Updating the GitHub Secret

1. Go to the repository settings: `Settings` → `Secrets and variables` → `Actions`
2. Find the existing `COCOAPODS_TRUNK_TOKEN` secret and update it
