# Projeko — Square subscriptions (staging specification)

Status: **NOT ENABLED**. No live payment, checkout or entitlement enforcement is deployed by this file.

## Plan
- Entrepreneur: CAD $20.00 per month, 30-day free trial.
- Client: free.
- One entrepreneur account and subscription across mobile and web.
- Payment collection begins only after Square production setup and successful sandbox tests.
- Trial conversion, renewal, failed-payment handling and cancellation must be disclosed clearly in the UI before consent.

## Implementation checklist
1. Confirm Square merchant account supports Canadian CAD subscriptions and trial configuration; create Square plan variation with monthly cadence and 30-day trial, and retain IDs in server-only environment variables.
2. Add server-side authenticated subscription checkout; associate the Square customer/subscription with the Supabase user ID. Never trust client-submitted role, price, or subscription status.
3. Verify Square webhook signatures against the raw request body. Make processing idempotent using unique Square event IDs; reconcile subscription state with Square API.
4. Persist entrepreneur subscription status, trial end and paid-through timestamp in Supabase with restrictive RLS; only server-side privileged functions may update entitlements.
5. Provide clear account billing status and cancellation flow, and prevent accidental duplicate subscriptions.
6. Test free trial, renewal, cancellation, payment failure, replayed webhooks, role boundaries and mobile/desktop parity in sandbox.
7. Configure Square credentials and payout banking in merchant dashboard later; enable production billing only after explicit approval.

Do not change the current production mobile application or website as part of this preparation.
