# Cloud Functions for tasks

This folder contains a callable function `adminUpsertUser` that creates or updates a Firebase Auth user.
It returns plain JSON (no Timestamp/Int64) to avoid Flutter web errors like `Int64 accessor not supported by dart2js`.

## Deploy

1. Install deps

   ```bash
   cd functions
   npm install
   ```

2. Build and deploy

   ```bash
   npm run deploy
   ```

Ensure you are logged in to Firebase CLI and the project is set to your app's project.

## Security

- The callable requires the caller to be authenticated. For production, restrict further (e.g., check custom claims or allowlist). Example snippet:

```ts
if (!(context.auth?.token?.admin === true)) {
  throw new functions.https.HttpsError('permission-denied', 'Admin only');
}
```

Set the `admin` custom claim using an admin script or Functions on role changes.
