## Custom ALB Module

This module creates perimeter ALB resources for the custom ingress profile.

It supports:
- Dual target groups (HTTP1 and HTTP2)
- Custom listener rules with host/path/source-ip/http-header conditions
- Optional OIDC authentication per listener rule

This module is intended to be selected by Terragrunt when `INGRESS_PROFILE=custom`.
