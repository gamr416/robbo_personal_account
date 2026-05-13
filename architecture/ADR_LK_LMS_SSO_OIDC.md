# ADR: LK <-> LMS SSO via OIDC

## Status
Accepted

## Context
- LMS (Open edX Tutor 11.10) already runs in production.
- LK is still pre-production and can absorb most changes.
- Required UX: click `LMS` in LK and enter LMS with active authorization.

## Decision
- Use Open edX as OIDC provider (IdP).
- Use LK as OIDC client with Authorization Code + PKCE.
- Keep identity ownership in IdP; LK stores mapping `external_sub = id_token.sub`.
- Enable rollout via feature flag `LK_SSO_WITH_LMS_ENABLED`.

## Consequences
- Minimal risk for production LMS: mainly client registration and endpoint sharing.
- Most implementation complexity remains in LK callback/session flow.
- No hard requirement to replicate user DB from LMS into LK.

## Required contract
- `OIDC_ISSUER`
- `OIDC_AUTHORIZATION_ENDPOINT`
- `OIDC_TOKEN_ENDPOINT`
- `OIDC_JWKS_URI`
- `OIDC_CLIENT_ID`
- `OIDC_REDIRECT_URI`

## Optional contract
- `OIDC_USERINFO_ENDPOINT`
- `OIDC_LOGOUT_ENDPOINT`
- `OIDC_POST_LOGOUT_REDIRECT_URI`
