# Ohana Family guardian backend

This directory contains the deployable, minimal-data backend for the optional
Ohana Family guardian feature. It is deliberately independent from the app's
local care database: no names, profile details, scores, health, pet, plant,
expense, or free-text care data belong in this service.

The shipping app keeps `OHANAGuardianSafetyEnabled` false. Do not enable the
client or publish the Family SKU until this stack is deployed in
`eu-central-1`, its public HTTPS host is added to the app's Associated Domains,
App Store Server Notifications V2 is configured, and the two-device APNs gates
in `docs/specs/GuardianSafety-logic.md` pass.

## Resources

- Cognito User Pool + Sign in with Apple federation
- API Gateway HTTP API with Cognito JWT authorization
- DynamoDB single table with point-in-time recovery and TTL
- EventBridge Scheduler evaluator
- SQS push queue and DLQs
- Lambda API, evaluator, push worker, and retention janitor
- Existing SNS APNS/APNS_SANDBOX platform application ARNs supplied as
  deployment parameters

## Deployment inputs

The template never contains Apple credentials. Supply:

- the Apple Service ID, Team ID, Key ID, and a Secrets Manager dynamic
  reference for the Sign in with Apple private key;
- Apple bundle ID and numeric App Apple ID;
- a Secrets Manager secret containing JSON `{ "certificates": ["<base64 DER>"] }`
  for Apple root certificates used by Apple's App Store Server Library;
- production and sandbox SNS platform application ARNs;
- a public HTTPS invite base URL and the App Store URL.

Build and deploy with AWS SAM using an operator account scoped to
`eu-central-1`. After deployment, construct the App Store Server Notifications
V2 URL from the API base URL and the securely held audience-token parameter;
the complete callback URL is intentionally not a CloudFormation output. Enter
it directly in App Store Connect and exercise Apple's test-notification
endpoint. Never log request bodies, callback tokens, or JWS values.

## Tests

Pure scheduling and incident rules require only the Python standard library:

```sh
python3 -m unittest discover -s backend/guardian/tests -v
```

AWS integration tests require a separately provisioned disposable stack. Real
delivery status remains `submitted` until the app opens or confirms an event;
an SNS message ID is not proof that a person received a notification.
