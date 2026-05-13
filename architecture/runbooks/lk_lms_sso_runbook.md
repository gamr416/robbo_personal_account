# Runbook: LK -> LMS SSO (OIDC)

## Symptoms and checks

1. User clicks `LMS` and remains in LK
- Check `LK_SSO_WITH_LMS_ENABLED`.
- Check required OIDC env values are not empty.

2. Callback returns error
- Inspect query params: `error`, `error_description`.
- Typical causes:
  - `access_denied`
  - redirect URI mismatch in IdP client settings.

3. `invalid_state`
- State in callback differs from session state.
- Ask user to retry from fresh LK tab/session.

4. Token exchange fails
- Verify `OIDC_TOKEN_ENDPOINT` is reachable from LK host.
- Verify `client_id`, `redirect_uri`, and PKCE code verifier.

5. `invalid_issuer` or `invalid_audience`
- Verify `OIDC_ISSUER` equals token `iss`.
- Verify `OIDC_CLIENT_ID` equals token `aud`.

6. `token_expired`
- Check server/client clock skew.

## Minimum logs to inspect
- `authorize_redirect_started`
- `sso_success`
- `sso_error`

## Rollback
- Set `LK_SSO_WITH_LMS_ENABLED=false`.
- LK will use direct LMS URL fallback.
