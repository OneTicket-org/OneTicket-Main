# Constraints: security

Tags (**MUST**, **SHOULD**, **DOMAIN**, **INFO**, **TODO**): see [README.md](README.md).

## Security

### Authentication
- **MUST** Keycloak provides identity (OIDC) as standard project infrastructure
- **SHOULD** Every service verifies the JWT on every hop — the gateway is not a trust boundary; the edge also rejects requests without a valid token before they consume capacity
- **SHOULD** Bearer JWTs issued by Keycloak are verified by signature, carrying the caller identity, with no session store on the hot path
- **SHOULD** Authentication runs in application middleware (TLS terminates at the edge with certificates managed in one place)
- **SHOULD** OpenAPI declares the `bearerAuth` scheme (JWT in `Authorization`) globally, overridden per operation.
- **SHOULD** 401 when credentials are missing/invalid (logged at INFO and counted as a security signal); 403 when the caller is known but denied (WARN with principal)
- **SHOULD** Secrets are never committed nor placed in the image; they are injected at deployment time; Rust dev uses a `.env` (dotenvy) with only `.env.example` committed
