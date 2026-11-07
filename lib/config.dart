// ---------------------------------------------------------------------------
// App configuration
// ---------------------------------------------------------------------------

/// How long a customer may be away before the mock session is dropped.
///
/// Measured against the last activity we persisted — written when the app goes
/// to the background and at most once a minute while the customer is touching
/// the screen — so the app can never sign anyone out while it is open and in
/// use.
///
/// CLIENT-SIDE ONLY. This app has no backend, so the limit is enforced by the
/// Flutter app itself and a user with a rooted phone could edit it. With a real
/// backend the server must enforce the same window: a short-lived access token
/// plus a refresh token, with the refresh endpoint rejecting anything older
/// than this limit. The client check below is then only a UX shortcut, never
/// the security boundary.
const Duration kSessionAwayLimit = Duration(minutes: 30);
