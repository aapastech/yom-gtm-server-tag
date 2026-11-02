# YOM Analytics Server: Google Tag Manager server-side tag

A server container (sGTM) tag template for [YOM (Your Own Metrics)](https://yom.aapastech.com/). It takes GA4 events your server container receives and sends ecommerce and lead events to YOM's server ingest. Each request is signed with your secret key; the key itself is never sent.

## What it does

- Sends `view_item`, `add_to_cart`, `begin_checkout`, `purchase`, `refund` and `generate_lead` from the GA4 event model to `https://ingest.yourownmetrics.aapastech.com/v2/events`. That is the only host it may call.
- Signs every request with HMAC-SHA256. The `YOM-Key-Id` and `YOM-Signature: t=<unix>,v1=<hex>` headers cover the timestamp and the exact body.
- Uses `transaction_id` as the purchase's event id. A refund with `refund_id` gets `<transaction_id>:refund:<refund_id>`. The browser's YOM tag uses the same ids, so YOM counts an order once.
- Carries consent. Analytics and marketing consent come from the hit's Consent Mode (`gcs` / `gcd`) or from fields you set, and GPC comes from the browser's `Sec-GPC` header. Consent the tag can't read is sent as unknown, never as granted. Marketing needs both `ad_storage` and `ad_user_data` granted.
- Sends no personal data. `user_data`, `user_id`, `ip_override`, page titles and any text containing `@` stay in your container. Page URLs are sent as paths, referrers as hosts, UTM tags as values and click ids only as present/absent flags. The GA4 client id goes along as YOM's visitor id only when analytics consent is granted.

## Set up

1. In YOM, open **Settings → API keys** and create a **secret key** with the **server** scope. Note its key id (`key_…`).
2. In your server container, go to **Templates → Tag templates → Search Gallery**, find **YOM Analytics Server** and add it.
3. Create a tag, paste the secret key and key id, and leave the consent source on "Consent Mode in the GA4 hit".
4. Trigger it on the GA4 client's events: Custom trigger, Client Name equals GA4.
5. Preview and check the requests (202 means YOM accepted them), then publish.

Store the secret key in a constant variable that only container admins can edit.

## Support

[yom.aapastech.com/contact](https://yom.aapastech.com/contact) · [Privacy](https://yom.aapastech.com/privacy) · [Terms](https://yom.aapastech.com/terms). Issues on this repository are welcome.

Licensed under Apache 2.0. This repository contains the tag template only.
