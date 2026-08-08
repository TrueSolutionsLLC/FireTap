# FireTap website

Static production marketing site for [firetap.app](https://firetap.app), hosted by Firebase Hosting in the `firetap-truesolutions` project.

The website is intentionally isolated from the iOS target. Its privacy, terms, and support pages preserve the production legal copy used by the shipped app.

## Local preview

```sh
cd website
firebase emulators:start --only hosting --project firetap-truesolutions
```

## Deploy

```sh
cd website
firebase deploy --only hosting --project firetap-truesolutions
```
