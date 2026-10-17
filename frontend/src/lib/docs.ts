export type Method = "GET" | "POST" | "PATCH" | "PUT" | "DELETE" | "WS";
export type Scope = "public" | "manage" | "admin";

export interface Endpoint {
  method: Method;
  path: string;
  desc: string;
  body?: string;
  returns?: string;
  try?: boolean;
  dry?: boolean;
  query?: { name: string; example?: string }[];
}

export interface Group {
  id: string;
  title: string;
  scope: Scope;
  auth?: string;
  blurb: string;
  endpoints: Endpoint[];
}

export const rank = (role?: string | null): number =>
  role === "superadmin" ? 2 : role === "admin" ? 1 : 0;

export const groups: Group[] = [
  {
    id: "webring",
    title: "Webring",
    scope: "public",
    blurb:
      "The ring itself. Contains the server metadata, members and the redirect endpoints.",
    endpoints: [
      {
        method: "GET",
        path: "/api/server-info",
        desc: "Name, version, authors, uptimes.",
        returns:
          "{name, version, description, authors[], license, source, server_uptime, system_uptime}",
      },
      {
        method: "GET",
        path: "/api/uptime",
        desc: "App and host uptime.",
        returns: "{app_uptime, system_uptime}",
      },
      {
        method: "GET",
        path: "/api/stats",
        desc: "Ring counters.",
        returns: "{members, ads, visits, unique_visits}",
      },
      {
        method: "GET",
        path: "/api/users",
        desc: "Verified members in ring order.",
        returns: "{users:[{username, url}]}",
      },
      {
        method: "GET",
        path: "/api/users/random",
        desc: "Redirects to a random member's site.",
        returns: "HTTP 307 redirect",
      },
      {
        method: "GET",
        path: "/api/ads",
        desc: "All verified ads.",
        returns: "{ ads: [{ username, image_url, ad_url }] }",
      },
      {
        method: "GET",
        path: "/api/ads/random",
        desc: "A random verified ad.",
        returns: "{username, image_url, ad_url}",
      },
      {
        method: "GET",
        path: "/user/:name",
        desc: "Redirects to that member's url (:name={username} explains itself).",
        returns: "HTTP 307 redirect",
      },
      {
        method: "GET",
        path: "/user/:name/next",
        desc: "Next site in the ring.",
        returns: "HTTP 307 redirect",
      },
      {
        method: "GET",
        path: "/user/:name/prev",
        desc: "Previous site in the ring.",
        returns: "HTTP 307 redirect",
      },
      {
        method: "GET",
        path: "/user/:name/random",
        desc: "Jump to a random site.",
        returns: "HTTP 307 redirect",
      },
      {
        method: "GET",
        path: "/api/user/:name",
        desc: "Alias of /user/:name.",
        returns: "HTTP 307 redirect",
      },
      {
        method: "GET",
        path: "/api/user/:name/next",
        desc: "Alias of /user/:name/next.",
        returns: "HTTP 307 redirect",
      },
      {
        method: "GET",
        path: "/api/user/:name/prev",
        desc: "Alias of /user/:name/prev.",
        returns: "HTTP 307 redirect",
      },
      {
        method: "GET",
        path: "/api/user/:name/random",
        desc: "Alias of /user/:name/random.",
        returns: "HTTP 307 redirect",
      },
    ],
  },
  {
    id: "newsletter",
    title: "Newsletter",
    scope: "public",
    blurb: "Public posts and the RSS feed.",
    endpoints: [
      {
        method: "GET",
        path: "/newsletter/feed.xml",
        desc: "RSS 2.0 feed.",
        returns: "application/rss+xml",
      },
      {
        method: "GET",
        path: "/api/newsletter",
        desc: "Published posts, newest first (drafts and future-dated posts hidden).",
        returns:
          "{newsletter:[{id, slug, title, content_markdown, status, posted_at, edited_at}]}",
      },
      {
        method: "GET",
        path: "/api/newsletter/:id",
        desc: "One post by id or slug.",
        returns:
          "{id, slug, title, content_markdown, status, posted_at, edited_at}",
      },
      {
        method: "WS",
        path: "/api/newsletter/ws",
        desc: "Live newsletter changes (create/update/delete).",
        returns: "WebSocket",
        try: false,
      },
    ],
  },
  {
    id: "join",
    title: "Join the ring",
    scope: "public",
    blurb:
      "Open signup, rate-limited per IP (5/min soft, plus a long-window hard cap).",
    endpoints: [
      {
        method: "POST",
        path: "/api/users",
        desc: "Register a site; returns a one-time manage token. 429 when over the per-IP soft (5/min) or hard cap.",
        body: '{\n  "username": "yourname",\n  "url": "https://your.site",\n  "contact": "you@example.com"\n}',
        returns: "{user, manage_token}",
      },
    ],
  },
  {
    id: "manage",
    title: "Manage your entry",
    scope: "manage",
    auth: "Authorization: Bearer <manage_token>",
    blurb:
      "Self-service for a member's ring entry and ad, gated by the token minted at signup.",
    endpoints: [
      {
        method: "GET",
        path: "/api/manage",
        desc: "Your user entry.",
        returns:
          "{id, username, url, contact, verified, created_at, edited_at, verified_at, manage_token_created_at, manage_token_last_used_at}",
      },
      {
        method: "PATCH",
        path: "/api/manage",
        desc: "Update url and/or contact (a new url also rewrites your ad's url).",
        body: '{\n  "url": "https://your.site",\n  "contact": "you@example.com"\n}',
        returns: '{...user} — 304 "No changes made" if identical',
      },
      {
        method: "DELETE",
        path: "/api/manage",
        desc: "Delete yourself from the ring.",
        returns: "{message}",
      },
      {
        method: "GET",
        path: "/api/manage/ad",
        desc: "Your ad.",
        returns:
          "{id, username, image_url, ad_url, verified, created_at, edited_at, verified_at}",
      },
      {
        method: "POST",
        path: "/api/manage/ad",
        desc: "Submit an ad (ad_url auto-follows your url).",
        body: '{\n  "image_url": "https://your.site/ad.png"\n}',
        returns: '{...ad} — 409 "Ad already exists"',
      },
      {
        method: "PATCH",
        path: "/api/manage/ad",
        desc: "Change the ad image.",
        body: '{\n  "image_url": "https://your.site/ad.png"\n}',
        returns: "{...ad} — 304 if unchanged, 404 if none",
      },
      {
        method: "DELETE",
        path: "/api/manage/ad",
        desc: "Remove your ad.",
        returns: "{message}",
      },
    ],
  },
  {
    id: "admin",
    title: "Admin",
    scope: "admin",
    auth: "Session cookie, sign in at /login",
    blurb: "Moderation, accounts, notifications, newsletter and webhooks.",
    endpoints: [
      {
        method: "POST",
        path: "/api/admin/login",
        desc: "Sign in; sets the session cookie.",
        body: '{\n  "username": "admin",\n  "password": "…"\n}',
        returns: "{username, role}",
      },
      {
        method: "GET",
        path: "/api/admin/logout",
        desc: "Clear the session.",
        returns: "{message}",
        dry: true,
      },
      {
        method: "GET",
        path: "/api/admin/me",
        desc: "Who am I.",
        returns: "{username, role}",
      },
      {
        method: "GET",
        path: "/api/admin/accounts",
        desc: "List accounts.",
        returns:
          "{accounts:[{username, role, auth_version, created_at, updated_at}]}",
      },
      {
        method: "POST",
        path: "/api/admin/accounts",
        desc: "Create an admin (superadmin only).",
        body: '{\n  "username": "mod",\n  "password": "…",\n  "role": "admin"\n}',
        returns: "{username, role}",
      },
      {
        method: "DELETE",
        path: "/api/admin/accounts/:name",
        desc: "Delete a lower-ranked account.",
        returns: "{message}",
      },
      {
        method: "POST",
        path: "/api/admin/accounts/:name/username",
        desc: "Rename an account (self or lower rank); bumps its auth_version.",
        body: '{\n  "username": "newname"\n}',
        returns: "{username} (self: re-issues the session cookie)",
      },
      {
        method: "POST",
        path: "/api/admin/accounts/:name/password",
        desc: "Reset a password (self or lower rank).",
        body: '{\n  "password": "…"\n}',
        returns: "{message}",
      },
      {
        method: "GET",
        path: "/api/admin/users/unverified",
        desc: "Pending members.",
        returns: "{users:[...]}",
      },
      {
        method: "GET",
        path: "/api/admin/ads/unverified",
        desc: "Pending ads.",
        returns: "{ads:[...]}",
      },
      {
        method: "POST",
        path: "/api/admin/users/:name/verify",
        desc: "Approve a member.",
        returns: "{...user}",
      },
      {
        method: "POST",
        path: "/api/admin/ads/:name/verify",
        desc: "Approve an ad.",
        returns: "{...ad}",
      },
      {
        method: "DELETE",
        path: "/api/admin/users/:name",
        desc: "Delete a member.",
        returns: "{message}",
      },
      {
        method: "DELETE",
        path: "/api/admin/ads/:name",
        desc: "Delete an ad.",
        returns: "{message}",
      },
      {
        method: "GET",
        path: "/api/admin/users",
        desc: "All members, paginated.",
        query: [
          { name: "q", example: "" },
          { name: "limit", example: "50" },
          { name: "offset", example: "0" },
        ],
        returns:
          "{users:[{id, username, url, contact, verified, created_at, edited_at, verified_at, manage_token_created_at, manage_token_last_used_at}], total}",
      },
      {
        method: "GET",
        path: "/api/admin/ads",
        desc: "All ads.",
        query: [
          { name: "q", example: "" },
          { name: "limit", example: "50" },
          { name: "offset", example: "0" },
        ],
        returns:
          "{ads:[{id, username, image_url, ad_url, verified, created_at, edited_at, verified_at}], total}",
      },
      {
        method: "POST",
        path: "/api/admin/users",
        desc: "Create a member; returns a one-time manage token.",
        body: '{\n  "username": "member",\n  "url": "https://member.site",\n  "contact": "member@example.com",\n  "verified": true\n}',
        returns: "{user, manage_token}",
      },
      {
        method: "PATCH",
        path: "/api/admin/users/:name",
        desc: "Update a member's url and/or contact (a new url also rewrites their ad's ad_url).",
        body: '{\n  "url": "https://member.site",\n  "contact": "member@example.com"\n}',
        returns: "{...user}",
      },
      {
        method: "POST",
        path: "/api/admin/users/:name/token",
        desc: "Rotate a member's manage token; returns the new one once.",
        returns: "{manage_token}",
      },
      {
        method: "POST",
        path: "/api/admin/ads",
        desc: "Create an ad for a member (ad_url auto-follows their url).",
        body: '{\n  "username": "member",\n  "image_url": "https://member.site/ad.png"\n}',
        returns: "{...ad}",
      },
      {
        method: "PATCH",
        path: "/api/admin/ads/:name",
        desc: "Change an ad's image_url and/or ad_url.",
        body: '{\n  "image_url": "https://member.site/ad.png"\n}',
        returns: "{...ad}",
      },
      {
        method: "GET",
        path: "/api/admin/blocked-words/:scope",
        desc: "Blocked terms for user_url | ad_url | global.",
        returns: "{scope, enforced_by, keywords, patterns, updated_at}",
      },
      {
        method: "PUT",
        path: "/api/admin/blocked-words/:scope",
        desc: "Replace blocked terms.",
        body: '{\n  "keywords": ["casino"],\n  "patterns": ["fre[e3]"]\n}',
        returns: "{...blocked-words}",
      },
      {
        method: "GET",
        path: "/api/admin/notifications",
        desc: "Notification history.",
        returns:
          "{notifications:[{id, kind, action, username, content, ref_id, target, created_at, read}]}",
      },
      {
        method: "DELETE",
        path: "/api/admin/notifications",
        desc: "Clear history.",
        returns: "{message}",
      },
      {
        method: "POST",
        path: "/api/admin/notifications/read",
        desc: "Mark notifications read (no body = all, or {ids:[...]}).",
        returns: "{message}",
      },
      {
        method: "WS",
        path: "/api/admin/notifications/ws",
        desc: "Live notification stream.",
        returns: "WebSocket",
        try: false,
      },
      {
        method: "DELETE",
        path: "/api/admin/access-log",
        desc: "Truncate the on-disk access log. Visit statistics are untouched.",
        returns: "{message}",
      },
      {
        method: "GET",
        path: "/api/admin/newsletter",
        desc: "All posts incl. drafts and scheduled.",
        returns:
          "{newsletter:[{id, slug, title, content_markdown, status, posted_at, edited_at}]}",
      },
      {
        method: "POST",
        path: "/api/admin/newsletter",
        desc: "Create a post. status: published | draft; posted_at (epoch secs) schedules a future publish.",
        body: '{\n  "title": "Hello",\n  "slug": "hello",\n  "content_markdown": "…",\n  "status": "published"\n}',
        returns: "{...entry}",
      },
      {
        method: "PATCH",
        path: "/api/admin/newsletter/:id",
        desc: "Edit a post.",
        body: '{\n  "title": "Hello"\n}',
        returns: "{...entry}",
      },
      {
        method: "DELETE",
        path: "/api/admin/newsletter/:id",
        desc: "Delete a post.",
        returns: "{message}",
      },
      {
        method: "GET",
        path: "/api/admin/webhooks",
        desc: "List webhooks.",
        returns:
          "{webhooks:[{id, url, format, events, enabled, created_at, updated_at, secret, last_status, last_error, last_delivered_at}]}",
      },
      {
        method: "POST",
        path: "/api/admin/webhooks",
        desc: "Add a webhook (generic | discord | slack).",
        body: '{\n  "url": "https://hooks.example/…",\n  "format": "discord",\n  "events": ["*"]\n}',
        returns:
          "{...webhook} - includes generated `secret`; deliveries carry `X-PetRing-Signature: sha256=<hmac>`",
      },
      {
        method: "PATCH",
        path: "/api/admin/webhooks/:id",
        desc: "Edit a webhook.",
        body: '{\n  "enabled": false\n}',
        returns: "{...webhook}",
      },
      {
        method: "DELETE",
        path: "/api/admin/webhooks/:id",
        desc: "Delete a webhook.",
        returns: "{message}",
      },
      {
        method: "POST",
        path: "/api/admin/webhooks/:id/test",
        desc: "Send a test payload.",
        returns: "{status, code}",
      },
      {
        method: "GET",
        path: "/api/admin/events",
        desc: 'Known webhook event names (static; "*" = all).',
        returns: '{events:["user.submit", "ad.submit", "*"]}',
      },
    ],
  },
];
