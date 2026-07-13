/// Base URL of the Firebase Cloud Function (`backend/functions`, exported as
/// `adminApi`) that performs privileged operations requiring the Firebase Admin
/// SDK — e.g. fully deleting a user's Auth login, which the Flutter client can
/// never do directly.
const adminApiBaseUrl = 'https://us-central1-leasely-a11e4.cloudfunctions.net/adminApi';
