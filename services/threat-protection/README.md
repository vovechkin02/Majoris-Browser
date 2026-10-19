# Managed threat service deployment component

This optional GPL-3.0 repository component is separate from the Browser. It has
not been deployed. Its deterministic tests substitute the provider; they do not
establish Google entitlement, infrastructure availability or live protection.

The accountable operator must first establish permitted Google Web Risk use,
billing, quotas, attribution, end-user disclosure, retention and incident
response under the [current service terms](https://cloud.google.com/terms/service-terms#web-risk).
Review that the managed-client deployment model is permitted; this component
does not grant permission to proxy or resell Google services. No Google key is
embedded in the Browser. Do not use non-commercial Safe Browsing as a substitute.

Deploy Python 3.11+ on a dedicated host/container/account, create the
`majoris-threat` service user, copy `server.py` to `/opt/majoris-threat`, and
prepare `/etc/majoris-threat/config.json` from the example. Defaults deliberately
refuse startup. After authorisation, acknowledge `provider_use_authorised` and
provide the server-side key file readable only by the service account. Provision
cryptographically random per-installation bearer tokens (at least 32 random
bytes); put only their SHA-256 hashes in `client_token_sha256`. Store the raw
client token in Browser Secret Service provider `managed-web-risk`, never in
GSettings or a desktop file. Tokens in unit tests are fixtures, not credentials.

Use the systemd unit and a reviewed TLS reverse proxy configuration. The server
binds only 127.0.0.1; expose only HTTPS through the proxy. Apply connection/header
limits, firewall rules, certificates and private-key permissions. The examples
also rate-limit unauthenticated requests by IP before backend token comparisons;
review the example's 10 requests/second and burst 20 for shared-network clients.
Authenticated per-client/provider quotas remain separate from this abuse limit.
The reverse-proxy example needs target configuration/certificate validation.
The examples disable request/error URL logs, including proxy logs. Establish separate
aggregate status-code/latency/resource monitoring without destinations or tokens.
The backend limits concurrent connections to 32, provider work to eight,
provider deadlines to two seconds, response bodies to 64 KiB, and requests by
client and globally. Multi-replica deployments need coordinated global quotas
or conservatively partitioned budgets; the included limiter is process-local.
In-memory quotas contain known token hashes and request timestamps; the proxy
keeps transient IP rate counters. Document these operational metadata uses in
the operator privacy policy. Restart clears backend counters.
There is no persistent URL cache or browsing-history log. Only the fixed Google
lookup endpoint is contacted; destination websites are never fetched.

The Browser endpoint is `https://OPERATOR/v1/uris:search`. Keep its existing GET
contract: one `uri`, exactly the three supported threatTypes, bearer auth.
Invalid/auth/quota/provider failures return 400/401/429/503, never a clean
verdict. Google categories/expiry are normalized, with advisory attribution
retained by the Browser. `/health` also requires bearer auth and reports 503
until a real successful provider lookup, then expires after 60 seconds; any
provider error clears health. It is not an entitlement or signature-freshness
attestation. Avoid paid synthetic probes without an operator-approved budget.

Rotation: provision new client tokens, temporarily allow old and new token
hashes, restart the service, update clients, then remove revoked hashes and
restart. Rotate the Google key file and restart; revoke old credentials at the
provider. Use service-manager restarts and monitored rollout; do not claim zero
downtime. No Browser process installs or starts this service. Configuration
changes never grant the user's separate endpoint-bound full-URL consent.

Before deployment qualify TLS, secrets permissions, revocation/rotation,
auth/quota failures, live harmless Google test URLs, billing, cancellation,
backend restart, failure monitoring and operator privacy/terms review. Do not
set Browser protection Active based on service installation or a config file.
Run local tests with `python3 services/threat-protection/test_server.py`.
