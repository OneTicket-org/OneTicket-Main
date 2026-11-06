# Constraints: security

Tags (**MUST**, **SHOULD**, **DOMAIN**, **INFO**, **TODO**): see [README.md](README.md).

## Security

### Authentication
- **MUST** [SEC-01] Keycloak provides identity (OIDC) as standard project infrastructure
- **SHOULD** [SEC-02] Every service verifies the JWT on every hop — the gateway is not a trust boundary; the edge also rejects requests without a valid token before they consume capacity
- **SHOULD** [SEC-03] Bearer JWTs issued by Keycloak are verified by signature, carrying the caller identity, with no session store on the hot path
- **SHOULD** [SEC-04] Authentication runs in application middleware (TLS terminates at the edge with certificates managed in one place)
- **SHOULD** [SEC-05] OpenAPI declares the `bearerAuth` scheme (JWT in `Authorization`) globally, overridden per operation.
- **SHOULD** [SEC-06] 401 when credentials are missing/invalid (logged at INFO and counted as a security signal); 403 when the caller is known but denied (WARN with principal)
- **SHOULD** [SEC-07] Secrets are never committed nor placed in the image; they are injected at deployment time; Rust dev uses a `.env` (dotenvy) with only `.env.example` committed
