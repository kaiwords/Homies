/// Base URL of the small Render-hosted backend (`backend/admin-api`) that
/// performs privileged operations requiring the Firebase Admin SDK — e.g.
/// fully deleting a user's Auth login, which the Flutter client can never
/// do directly. Fill this in after deploying that service to Render.
const adminApiBaseUrl = 'https://REPLACE-ME.onrender.com';
