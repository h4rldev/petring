# Privacy Policy

Last updated: 17th of October, 2026 (17-10-2026)

This Privacy Policy explains how h4rl ("we", "us") handles personal
information for the petRing webring and navlink-ad service (the "Service"),
including the public site, the ring and ad endpoints, the embeddable widgets,
the API, and the admin area.

By joining the ring, adding an ad, or otherwise using the Service you agree to
this policy. If you do not agree, please do not use the Service.

## Summary

- We collect only what the Service needs to run: your ring entry, an IP address
  for abuse prevention and aggregate visit counts, and, for administrators, an
  account.
- We do not collect email addresses, run analytics of our own, or use
  third-party tracking or advertising.
- Our DNS is proxied through Cloudflare, which also records cookie-free
  aggregate traffic analytics (retained for up to 31 days), and requests pass
  through a proof-of-work bot challenge (Anubis).
- We do not sell your personal information.
- You can view, edit and delete your ring entry yourself with your manage
  token at any time.

## 1. Who we are

The data controller for the Service is h4rl (an individual operator),
reachable at contact@h4rl.dev.
The Service is a community webring; it is not a commercial data broker.

## 2. Information we collect

### 2.1 Information you give us

When you join the ring through the homepage form, we store:

- **Username**: your display name in the ring. This is public.
- **URL**: the address of your website. This is public.
- **Contact**: an optional "how to reach you" note. This is visible to admins
  only, and is not shown in the public ring.
- **Submit IP**: the IP address the submission came from, stored with the entry
  as a record of its origin. Spam and duplicate protection is handled separately
  (short-lived in-memory rate limiting and username/URL uniqueness), not by this
  field.
- **Manage token**: a one-time token used to manage your entry. Only a
  SHA-256 hash is stored; the plaintext token is shown to you once and is never
  stored or shown again.
- **Timestamps**: when the entry was created, last edited and (if applicable)
  verified.

When you add a navlink ad, we store the **image URL** and **ad URL**. Both are
public, and the ad URL follows your site URL.

### 2.2 Information collected automatically

- **Visit statistics**: for each HTML page view we record the visitor's IP
  address together with a hit count and first-seen / last-seen timestamps. This
  is used to show aggregate numbers (total and unique visits). API requests are
  not counted.
- **Access logs**: if the operator enables access logging, we record the
  request method, path, response status, IP address and duration. This is used
  for security and troubleshooting, and may also be recorded by the underlying
  web server or reverse proxy.
- **Rate limiting**: submission attempts are counted per IP address in memory
  for a short window (about a minute) and a longer one (up to 14 days). This
  state is not persisted and is discarded automatically.
- **Admin notifications**: each new entry or ad creates an admin-only
  notification (the username and the submitted URL, or the ad's image URL) so
  administrators can review it. Notifications are never public and are kept
  until an administrator clears them.
- **Edge proxy and aggregate analytics**: our DNS is proxied through
  Cloudflare, which records aggregate traffic statistics such as request counts
  over time, data transfer, requests by status code, cache status, top paths,
  countries, browsers, operating systems, device types, user agents, HTTP
  versions and data centers, page views, visits, and mitigated requests. These
  statistics are aggregated: Cloudflare's free-plan analytics are cookie-free
  and do not use cross-site tracking or individual user fingerprints, and are
  not used to profile individuals. Cloudflare retains them for up to 31 days.
- **Bot protection**: the Service uses a proof-of-work bot challenge (Anubis),
  which sees your IP address and request metadata and runs a small
  proof-of-work challenge in your browser.

We do not record user-agent strings ourselves, and we do not use the IP data to
build profiles or track you across other websites.

### 2.3 Administrator account information

If you are given an administrator account, we store your **username** and an
**Argon2 password hash**. Passwords are never stored in plaintext. Signing in
also issues a session, described under Cookies below.

### 2.4 What we do not collect

We do not collect email addresses, real names, payment details, or precise
location. The newsletter is a public blog, not an email mailing list, so there
are no newsletter subscribers to store. We do not use third-party advertising
or tracking scripts.

## 3. Cookies

The Service sets one cookie of its own, plus a challenge cookie from its bot filter:

| Cookie | Set by | Purpose | Lifetime |
| --- | --- | --- | --- |
| `session` | petRing | Admin sign-in session (httpOnly, SameSite=Lax, Secure over HTTPS). Cleared on sign-out. | 30 days |
| Anubis challenge cookie | petRing (Anubis) | Remembers that you solved the proof-of-work challenge so you are not asked again on every request. | short |

The public site and the embeddable widgets work without the `session` cookie.
We do not set any advertising cookies and we do not permit third-party
cross-site tracking. Cloudflare's proxied DNS and aggregate traffic analytics
set no cookies.

All cookies we use are strictly necessary (administrator sign-in and bot
protection), so we do not show a cookie consent banner.

## 4. How we use your information

We use the information described above to:

- operate the webring and the navlink ads, including verifying entries;
- display the public ring and ad listings;
- prevent spam, abuse and duplicate submissions, and apply rate limits;
- produce aggregate statistics about members, ads and visits;
- protect the Service against bots and attacks;
- secure the Service and diagnose faults;
- authenticate administrators and manage accounts.

We do not use your information for automated decision-making or profiling, and
we do not use it for advertising.

## 5. Legal bases (EEA and UK)

Where the GDPR or UK GDPR applies, we rely on:

- **Consent** for information you choose to submit when joining the ring or
  adding an ad (you can withdraw it by deleting your entry).
- **Legitimate interests** for operating the Service, preventing spam and
  abuse, protecting the Service against bots, maintaining security, and
  producing aggregate statistics. These interests do not override your rights.
- **Legal obligation** where we are required to retain or disclose information
  by law.

## 6. Sharing your information

We do not sell your personal information, and we do not share it for
cross-context behavioural advertising.

We may share limited information in these cases:

- **Cloudflare**: our DNS is proxied through Cloudflare, which records the
  aggregate traffic statistics described above. Cloudflare processes IP
  addresses and request metadata to deliver the site and produce these
  statistics; it is not used for cross-site tracking or profiling.
- **Webhooks (operator configured)**: the operator may connect the Service to
  a chat service such as Discord or Slack so that admin notifications (for
  example, a new submission) are forwarded there. Those notifications can
  include the submitted username and URL (for an ad, the image URL); contact
  notes are never forwarded. This is configured by the operator, and only
  administrators receive these notifications.
- **Hosting**: the Service runs on infrastructure provided by Worldstream. The
  hosting provider and any reverse proxy may process IP addresses and request
  metadata in their own logs.
- **Legal requirements**: we may disclose information if required by law, or to
  protect the rights, property or safety of the Service or others.

Anubis is open-source bot-mitigation software run as part of our own service; it
is not a separate company.

## 7. International transfers

The Service is hosted by Worldstream in the Netherlands (EU), and Cloudflare
operates a global network that may process requests in the region closest to you. 
If the operator uses webhooks, the chat provider (for example Discord or Slack) 
may process the forwarded notification on servers in another country. Where 
required, we rely on appropriate safeguards for such transfers.

## 8. Data retention

- **Ring entries and ads**: kept until you delete them, or ask us to. Deleting
  an entry also deletes its ad.
- **Administrator accounts**: kept until the account is deleted.
- **Visit counters**: we keep a permanent count of unique visits. Each
  visitor's IP address is stored only as the counting key for that count. It is
  not linked to your ring entry, is not shown publicly, and is not used to
  profile you. Because the count is a permanent statistic, this key is kept for
  as long as the Service runs.
- **Access logs**: retained for as long as needed for security, and can be
  cleared at any time from the admin dashboard, unless a longer period is needed
  for security.
- **Rate-limit state**: discarded automatically, at the latest within 14 days.
- **Admin notifications**: kept until an administrator clears them.

Cloudflare retains its aggregate traffic analytics for up to 31 days; any
webhook provider retains data according to its own policies.

## 9. Security

We protect your information with measures including Argon2 password hashing,
SHA-256 hashing of manage tokens, httpOnly session cookies, bot and abuse
protection, and access controls on administrative features. No method of
storage or transmission is completely secure, so we cannot guarantee absolute
security.

If a security breach affects your personal data, we will notify the relevant
authorities and affected users without undue delay, where required by law.

## 10. Your rights

Depending on where you live, you may have the right to:

- access the personal information we hold about you;
- correct inaccurate information;
- delete your information;
- restrict or object to our processing;
- receive your information in a portable format;
- withdraw consent at any time, where processing is based on consent; and
- lodge a complaint with your local data protection authority (for example, 
  if you are in the Netherlands, the Autoriteit Persoonsgegevens).

You can exercise most of these yourself: use your manage token to view, update
or delete your ring entry and ad. For anything else, contact us at
contact@h4rl.dev. We will respond within the time required by applicable law.

If you are a California resident, you have the right to know, delete and
correct personal information, and to not be discriminated against for
exercising these rights. We do not sell or share your personal information as
those terms are defined by the CCPA/CPRA.

## 11. Children

The Service is not directed to children. If you are below the minimum age of
digital consent in your country, please do not submit an entry or use the
admin area.

## 12. Changes to this policy

We may update this policy from time to time. When we do, we will change the
"Last updated" date at the top. Material changes will be announced on the
Service where practical.

## 13. Contact

Questions about this policy or your information: contact@h4rl.dev.
