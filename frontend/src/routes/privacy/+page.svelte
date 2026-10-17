<svelte:head>
  <title>Privacy Policy - petRing</title>
  <link rel="canonical" href="https://webring.pet/privacy/" />
  <meta property="og:title" content="Privacy Policy - petRing" />
  <meta property="og:description" content="How petRing handles personal information." />
</svelte:head>

<section class="cell dither dither-corner">
  <h1>Privacy Policy</h1>
  <p class="lede">Last updated: 17th of October, 2026.</p>

  <p>
    This Privacy Policy explains how h4rl ("we", "us") handles personal information
    for the petRing webring and navlink-ad service (the "Service"), including the
    public site, the ring and ad endpoints, the embeddable widgets, the API, and the
    admin area.
  </p>
  <p>
    By joining the ring, adding an ad, or otherwise using the Service you agree to
    this policy. If you do not agree, please do not use the Service.
  </p>

  <h2>Summary</h2>
  <ul>
    <li>We collect only what the Service needs to run: your ring entry, an IP address for abuse prevention and aggregate visit counts, and, for administrators, an account.</li>
    <li>We do not collect email addresses, run analytics of our own, or use third-party tracking or advertising.</li>
    <li>Our DNS is proxied through Cloudflare, which also records cookie-free aggregate traffic analytics (retained for up to 31 days), and requests pass through a proof-of-work bot challenge (Anubis).</li>
    <li>We do not sell your personal information.</li>
    <li>You can view, edit and delete your ring entry yourself with your manage token at any time.</li>
  </ul>

  <h2>1. Who we are</h2>
  <p>
    The data controller for the Service is h4rl (an individual based in the
    Netherlands), reachable at <a href="mailto:contact@h4rl.dev">contact@h4rl.dev</a>.
  </p>

  <p>
    The Service is a community webring; it is not a commercial data broker.
  </p>
    
  <h2>2. Information we collect</h2>

  <h3>2.1 Information you give us</h3>
  <p>When you join the ring through the homepage form, we store:</p>
  <ul>
    <li><strong>Username</strong>: your display name in the ring. This is public.</li>
    <li><strong>URL</strong>: the address of your website. This is public.</li>
    <li><strong>Contact</strong>: an optional "how to reach you" note. This is visible to admins only, and is not shown in the public ring.</li>
    <li><strong>Submit IP</strong>: the IP address the submission came from, stored with the entry as a record of its origin. Spam and duplicate protection is handled separately (short-lived in-memory rate limiting and username/URL uniqueness), not by this field.</li>
    <li><strong>Manage token</strong>: a one-time token used to manage your entry. Only a SHA-256 hash is stored; the plaintext token is shown to you once and is never stored or shown again.</li>
    <li><strong>Timestamps</strong>: when the entry was created, last edited and (if applicable) verified.</li>
  </ul>
  <p>
    When you add a navlink ad, we store the <strong>image URL</strong> and
    <strong>ad URL</strong>. Both are public, and the ad URL follows your site URL.
  </p>

  <h3>2.2 Information collected automatically</h3>
  <ul>
    <li><strong>Visit statistics</strong>: for each HTML page view we record the visitor's IP address together with a hit count and first-seen / last-seen timestamps. This is used to show aggregate numbers (total and unique visits). API requests are not counted.</li>
    <li><strong>Access logs</strong>: if the operator enables access logging, we record the request method, path, response status, IP address and duration. This is used for security and troubleshooting, and may also be recorded by the underlying web server or reverse proxy.</li>
    <li><strong>Rate limiting</strong>: submission attempts are counted per IP address in memory for a short window (about a minute) and a longer one (up to 14 days). This state is not persisted and is discarded automatically.</li>
    <li><strong>Admin notifications</strong>: each new entry or ad creates an admin-only notification (the username and the submitted URL, or the ad's image URL) so administrators can review it. Notifications are never public and are kept until an administrator clears them.</li>
    <li><strong>Edge proxy and aggregate analytics</strong>: our DNS is proxied through Cloudflare, which records aggregate traffic statistics such as request counts over time, data transfer, requests by status code, cache status, top paths, countries, browsers, operating systems, device types, user agents, HTTP versions and data centers, page views, visits, and mitigated requests. These statistics are aggregated: Cloudflare's free-plan analytics are cookie-free and do not use cross-site tracking or individual user fingerprints, and are not used to profile individuals. Cloudflare retains them for up to 31 days.</li>
    <li><strong>Bot protection</strong>: the Service uses a proof-of-work bot challenge (Anubis), which sees your IP address and request metadata and runs a small proof-of-work challenge in your browser.</li>
  </ul>
  <p>
    We do not record user-agent strings ourselves, and we do not use the IP data to
    build profiles or track you across other websites.
  </p>

  <h3>2.3 Administrator account information</h3>
  <p>
    If you are given an administrator account, we store your <strong>username</strong>
    and an <strong>Argon2 password hash</strong>. Passwords are never stored in
    plaintext. Signing in also issues a session, described under Cookies below.
  </p>

  <h3>2.4 What we do not collect</h3>
  <p>
    We do not collect email addresses, real names, payment details, or precise
    location. The newsletter is a public blog, not an email mailing list, so there
    are no newsletter subscribers to store. We do not use third-party advertising or
    tracking scripts.
  </p>

  <h2>3. Cookies</h2>
  <p>
    The Service sets one cookie of its own, plus a challenge cookie from its bot filter:
  </p>
  <div class="scroll">
    <table>
      <thead>
        <tr><th>Cookie</th><th>Set by</th><th>Purpose</th><th>Lifetime</th></tr>
      </thead>
      <tbody>
        <tr>
          <td><code>session</code></td>
          <td>petRing</td>
          <td>Admin sign-in session (httpOnly, SameSite=Lax, Secure over HTTPS). Cleared on sign-out.</td>
          <td>30 days</td>
        </tr>
        <tr>
          <td>Anubis challenge cookie</td>
          <td>petRing (Anubis)</td>
          <td>Remembers that you solved the proof-of-work challenge so you are not asked again on every request.</td>
          <td>short</td>
        </tr>
      </tbody>
    </table>
  </div>
  <p>
    The public site and the embeddable widgets work without the <code>session</code>
    cookie. We do not set any advertising cookies and we do not permit third-party
    cross-site tracking. Cloudflare's proxied DNS and aggregate traffic analytics set
    no cookies.
  </p>
  <p>
    All cookies we use are strictly necessary (administrator sign-in and bot
    protection), so we do not show a cookie consent banner.
  </p>

  <h2>4. How we use your information</h2>
  <p>We use the information described above to:</p>
  <ul>
    <li>operate the webring and the navlink ads, including verifying entries;</li>
    <li>display the public ring and ad listings;</li>
    <li>prevent spam, abuse and duplicate submissions, and apply rate limits;</li>
    <li>produce aggregate statistics about members, ads and visits;</li>
    <li>protect the Service against bots and attacks;</li>
    <li>secure the Service and diagnose faults;</li>
    <li>authenticate administrators and manage accounts.</li>
  </ul>
  <p>
    We do not use your information for automated decision-making or profiling, and we
    do not use it for advertising.
  </p>

  <h2>5. Legal bases (EEA and UK)</h2>
  <p>Where the GDPR or UK GDPR applies, we rely on:</p>
  <ul>
    <li><strong>Consent</strong> for information you choose to submit when joining the ring or adding an ad (you can withdraw it by deleting your entry).</li>
    <li><strong>Legitimate interests</strong> for operating the Service, preventing spam and abuse, protecting the Service against bots, maintaining security, and producing aggregate statistics. These interests do not override your rights.</li>
    <li><strong>Legal obligation</strong> where we are required to retain or disclose information by law.</li>
  </ul>

  <h2>6. Sharing your information</h2>
  <p>
    We do not sell your personal information, and we do not share it for cross-context
    behavioural advertising.
  </p>
  <p>We may share limited information in these cases:</p>
  <ul>
    <li><strong>Cloudflare</strong>: our DNS is proxied through Cloudflare, which records the aggregate traffic statistics described above. Cloudflare processes IP addresses and request metadata to deliver the site and produce these statistics; it is not used for cross-site tracking or profiling.</li>
    <li><strong>Webhooks (operator configured)</strong>: the operator may connect the Service to a chat service such as Discord or Slack so that admin notifications (for example, a new submission) are forwarded there. Those notifications can include the submitted username and URL (for an ad, the image URL); contact notes are never forwarded. This is configured by the operator, and only administrators receive these notifications.</li>
    <li><strong>Hosting</strong>: the Service runs on infrastructure provided by Worldstream. The hosting provider and any reverse proxy may process IP addresses and request metadata in their own logs.</li>
    <li><strong>Legal requirements</strong>: we may disclose information if required by law, or to protect the rights, property or safety of the Service or others.</li>
  </ul>
  <p>
    Anubis is open-source bot-mitigation software run as part of our own service; it
    is not a separate company.
  </p>

  <h2>7. International transfers</h2>
  <p>
    The Service is hosted by Worldstream in the Netherlands (EU), and Cloudflare
    operates a global network that may process requests in the region closest to you.
    If the operator uses webhooks, the chat provider (for example Discord or Slack)
    may process the forwarded notification on servers in another country. Where
    required, we rely on appropriate safeguards for such transfers.
  </p>

  <h2>8. Data retention</h2>
  <ul>
    <li><strong>Ring entries and ads</strong>: kept until you delete them, or ask us to. Deleting an entry also deletes its ad.</li>
    <li><strong>Administrator accounts</strong>: kept until the account is deleted.</li>
    <li><strong>Visit counters</strong>: we keep a permanent count of unique visits. Each visitor's IP address is stored only as the counting key for that count. It is not linked to your ring entry, is not shown publicly, and is not used to profile you. Because the count is a permanent statistic, this key is kept for as long as the Service runs.</li>
    <li><strong>Access logs</strong>: retained for as long as needed for security, and can be cleared at any time from the admin dashboard, unless a longer period is needed for security.</li>
    <li><strong>Rate-limit state</strong>: discarded automatically, at the latest within 14 days.</li>
    <li><strong>Admin notifications</strong>: kept until an administrator clears them.</li>
  </ul>
  <p>
    Cloudflare retains its aggregate traffic analytics for up to 31 days; any webhook
    provider retains data according to its own policies.
  </p>

  <h2>9. Security</h2>
  <p>
    We protect your information with measures including Argon2 password hashing,
    SHA-256 hashing of manage tokens, httpOnly session cookies, bot and abuse
    protection, and access controls on administrative features. No method of storage
    or transmission is completely secure, so we cannot guarantee absolute security.
  </p>
  <p>
    If a security breach affects your personal data, we will notify the relevant
    authorities and affected users without undue delay, where required by law.
  </p>

  <h2>10. Your rights</h2>
  <p>Depending on where you live, you may have the right to:</p>
  <ul>
    <li>access the personal information we hold about you;</li>
    <li>correct inaccurate information;</li>
    <li>delete your information;</li>
    <li>restrict or object to our processing;</li>
    <li>receive your information in a portable format;</li>
    <li>withdraw consent at any time, where processing is based on consent; and</li>
    <li>lodge a complaint with your local data protection authority (for example, if you are in the Netherlands, the Autoriteit Persoonsgegevens).</li>
  </ul>
  <p>
    You can exercise most of these yourself: use your manage token to view, update or
    delete your ring entry and ad. For anything else, contact us at
    <a href="mailto:contact@h4rl.dev">contact@h4rl.dev</a>. We will respond within the
    time required by applicable law.
  </p>
  <p>
    If you are a California resident, you have the right to know, delete and correct
    personal information, and to not be discriminated against for exercising these
    rights. We do not sell or share your personal information as those terms are
    defined by the CCPA/CPRA.
  </p>

  <h2>11. Children</h2>
  <p>
    The Service is not directed to children. If you are below the minimum age of
    digital consent in your country, please do not submit an entry or use the admin
    area.
  </p>

  <h2>12. Changes to this policy</h2>
  <p>
    We may update this policy from time to time. When we do, we will change the "Last
    updated" date at the top. Material changes will be announced on the Service where
    practical.
  </p>

  <h2>13. Contact</h2>
  <p>
    Questions about this policy or your information:
    <a href="mailto:contact@h4rl.dev">contact@h4rl.dev</a>.
  </p>
</section>

<style>
  @reference '$appcss';

  h1 {
    @apply mb-2 font-sans text-3xl text-(--color-accent);
  }

  h2 {
    @apply mt-8 mb-2 text-xl;
  }

  h3 {
    @apply mt-5 mb-1.5 text-base font-bold;
  }

  p {
    @apply mb-3;
  }

  .lede {
    @apply mb-3 text-(--color-subtext);
  }

  ul {
    @apply mb-3 flex list-disc flex-col gap-1 pl-5;
  }

  a {
    @apply text-(--color-link);
  }

  .scroll {
    @apply mb-3 overflow-x-auto;
  }

  table {
    @apply w-full border-collapse text-sm;
  }

  th,
  td {
    @apply border border-(--color-surface-2) px-2 py-1 text-left align-top;
  }

  th {
    @apply bg-(--color-secondary);
  }

  code {
    @apply bg-(--color-bg) px-1;
  }
</style>
