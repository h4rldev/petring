const base_url = "";

export interface NewsletterEntry {
  id: number;
  slug: string;
  title: string;
  content_markdown: string;
  status: "draft" | "published";
  authors: string[];
  posted_at: number;
  edited_at: number | null;
}

export interface PublicUser {
  username: string;
  url: string;
}

export interface PublicAd {
  username: string;
  image_url: string;
  ad_url: string;
}

export interface RandomAd {
  username: string;
  image_url: string;
  ad_url: string;
}

export interface ServerInfo {
  name: string;
  version: string;
  description: string;
  authors: string[];
  license: string;
  source: string;
  server_uptime: string;
  system_uptime: string;
}

export interface CreatedUser {
  user: PublicUser;
  manage_token: string;
}

export interface ManagedUser {
  id: number;
  username: string;
  url: string;
  contact: string;
  verified: boolean;
  created_at: number;
  edited_at: number | null;
  verified_at: number | null;
  manage_token_created_at: number | null;
  manage_token_last_used_at: number | null;
}

export interface ManagedAd {
  id: number;
  username: string;
  image_url: string;
  ad_url: string;
  verified: boolean;
  created_at: number;
  edited_at: number | null;
  verified_at: number | null;
}

export interface Stats {
  members: number;
  ads: number;
  visits: number;
  unique_visits: number;
}

export interface Account {
  username: string;
  role: "admin" | "superadmin";
}

export interface Notification {
  id?: number;
  kind: string;
  action: string;
  username: string;
  content: string;
  ref_id: string;
  target: string;
  created_at: number;
  read: boolean;
}

export type NewsletterInput = Pick<
  NewsletterEntry,
  "title" | "slug" | "content_markdown" | "status"
> & { posted_at?: number };

export interface AccountInfo {
  username: string;
  role: string;
  auth_version: number;
  created_at: number;
  updated_at: number | null;
}

export interface BlockedWords {
  scope: string;
  enforced_by: string;
  keywords: string[];
  patterns: string[];
  updated_at: number | null;
}

export interface Webhook {
  id: number;
  url: string;
  format: "generic" | "discord" | "slack";
  events: string[];
  enabled: boolean;
  created_at: number;
  updated_at: number | null;
  secret: string | null;
  last_status: number | null;
  last_error: string | null;
  last_delivered_at: number | null;
}

export type WebhookInput = {
  url: string;
  format: Webhook["format"];
  events: string[];
  enabled?: boolean;
};

const request = async <T>(
  endpoint: string,
  method = "GET",
  body?: unknown,
): Promise<T> => {
  const res = await fetch(base_url + endpoint, {
    method,
    headers:
      body === undefined ? undefined : { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (res.status === 204) return null as T;
  const data = await res.json().catch(() => null);
  if (!res.ok)
    throw new Error((data && data.message) || `API error (${res.status})`);
  return data as T;
};

const manage_request = async <T>(
  endpoint: string,
  method: string,
  token: string,
  body?: unknown,
): Promise<T> => {
  const res = await fetch(base_url + endpoint, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (res.status === 204 || res.status === 304) return null as T;
  const data = await res.json().catch(() => null);
  if (!res.ok)
    throw new Error((data && data.message) || `API error (${res.status})`);
  return data as T;
};

const TOKEN_KEY = "petring_manage_token";

export const get_manage_token = () => {
  try {
    return localStorage.getItem(TOKEN_KEY) ?? sessionStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
};

export const set_manage_token = (t: string, remember = false) => {
  try {
    (remember ? localStorage : sessionStorage).setItem(TOKEN_KEY, t);
    (remember ? sessionStorage : localStorage).removeItem(TOKEN_KEY);
  } catch {}
};

export const clear_manage_token = () => {
  try {
    localStorage.removeItem(TOKEN_KEY);
    sessionStorage.removeItem(TOKEN_KEY);
  } catch {}
};

export interface ListOpts {
  q?: string;
  limit?: number;
  offset?: number;
}

const list_qs = ({ q, limit, offset }: ListOpts = {}): string => {
  const p = new URLSearchParams();
  if (q) p.set("q", q);
  if (limit !== undefined) p.set("limit", String(limit));
  if (offset !== undefined) p.set("offset", String(offset));
  const s = p.toString();
  return s ? `?${s}` : "";
};

export const api = {
  get_newsletter: async (): Promise<NewsletterEntry[]> =>
    (await request<{ newsletter: NewsletterEntry[] }>("/api/newsletter"))
      .newsletter,
  get_newsletter_entry: (
    id_or_slug: string | number,
  ): Promise<NewsletterEntry> =>
    request<NewsletterEntry>(`/api/newsletter/${id_or_slug}`),
  get_users: async (): Promise<PublicUser[]> =>
    (await request<{ users: PublicUser[] }>("/api/users")).users,
  get_ads: async (): Promise<PublicAd[]> =>
    (await request<{ ads: PublicAd[] }>("/api/ads")).ads,
  random_ad: () => request<RandomAd>("/api/ads/random"),
  server_info: () => request<ServerInfo>("/api/server-info"),
  create_user: (
    username: string,
    url: string,
    contact = "",
  ): Promise<CreatedUser> =>
    request<CreatedUser>("/api/users", "POST", { username, url, contact }),
  stats: () => request<Stats>("/api/stats"),

  manage: {
    get: (token: string) =>
      manage_request<ManagedUser>("/api/manage", "GET", token),
    update: (token: string, body: { url?: string; contact?: string }) =>
      manage_request<ManagedUser>("/api/manage", "PATCH", token, body),
    remove: (token: string) =>
      manage_request<{ message: string }>("/api/manage", "DELETE", token),

    get_ad: (token: string) =>
      manage_request<ManagedAd>("/api/manage/ad", "GET", token),
    create_ad: (token: string, image_url: string) =>
      manage_request<ManagedAd>("/api/manage/ad", "POST", token, { image_url }),
    update_ad: (token: string, image_url: string) =>
      manage_request<ManagedAd>("/api/manage/ad", "PATCH", token, {
        image_url,
      }),
    remove_ad: (token: string) =>
      manage_request<{ message: string }>("/api/manage/ad", "DELETE", token),
  },

  admin: {
    login: (username: string, password: string): Promise<Account> =>
      request<Account>("/api/admin/login", "POST", { username, password }),
    logout: (): Promise<{ message: string }> => request("/api/admin/logout"),
    me: () => request<Account>("/api/admin/me"),

    change_password: (
      name: string,
      password: string,
    ): Promise<{ message: string }> =>
      request(
        `/api/admin/accounts/${encodeURIComponent(name)}/password`,
        "POST",
        { password },
      ),
    change_username: (name: string, username: string): Promise<Account> =>
      request(
        `/api/admin/accounts/${encodeURIComponent(name)}/username`,
        "POST",
        { username },
      ),

    accounts: async (): Promise<AccountInfo[]> =>
      (await request<{ accounts: AccountInfo[] }>("/api/admin/accounts"))
        .accounts,
    create_account: (
      username: string,
      password: string,
      role: string,
    ): Promise<Account> =>
      request("/api/admin/accounts", "POST", { username, password, role }),
    delete_account: (name: string): Promise<{ message: string }> =>
      request(`/api/admin/accounts/${encodeURIComponent(name)}`, "DELETE"),

    unverified_users: async (): Promise<ManagedUser[]> =>
      (await request<{ users: ManagedUser[] }>("/api/admin/users/unverified"))
        .users,
    unverified_ads: async (): Promise<ManagedAd[]> =>
      (await request<{ ads: ManagedAd[] }>("/api/admin/ads/unverified")).ads,
    verify_user: (name: string): Promise<ManagedUser> =>
      request(`/api/admin/users/${encodeURIComponent(name)}/verify`, "POST"),
    verify_ad: (name: string): Promise<ManagedAd> =>
      request(`/api/admin/ads/${encodeURIComponent(name)}/verify`, "POST"),
    delete_user: (name: string): Promise<{ message: string }> =>
      request(`/api/admin/users/${encodeURIComponent(name)}`, "DELETE"),
    delete_ad: (name: string): Promise<{ message: string }> =>
      request(`/api/admin/ads/${encodeURIComponent(name)}`, "DELETE"),

    all_users: (
      opts?: ListOpts,
    ): Promise<{ users: ManagedUser[]; total: number }> =>
      request(`/api/admin/users${list_qs(opts)}`),
    all_ads: (opts?: ListOpts): Promise<{ ads: ManagedAd[]; total: number }> =>
      request(`/api/admin/ads${list_qs(opts)}`),

    create_user: (body: {
      username: string;
      url: string;
      contact?: string;
      verified?: boolean;
    }): Promise<{ user: ManagedUser; manage_token: string }> =>
      request("/api/admin/users", "POST", body),
    update_user: (
      name: string,
      body: { url?: string; contact?: string },
    ): Promise<ManagedUser> =>
      request(`/api/admin/users/${encodeURIComponent(name)}`, "PATCH", body),
    regenerate_token: (name: string): Promise<{ manage_token: string }> =>
      request(`/api/admin/users/${encodeURIComponent(name)}/token`, "POST"),

    create_ad: (body: {
      username: string;
      image_url: string;
    }): Promise<ManagedAd> => request("/api/admin/ads", "POST", body),
    update_ad: (
      name: string,
      body: { image_url?: string; ad_url?: string },
    ): Promise<ManagedAd> =>
      request(`/api/admin/ads/${encodeURIComponent(name)}`, "PATCH", body),

    notifications: async (): Promise<Notification[]> =>
      (
        await request<{ notifications: Notification[] }>(
          "/api/admin/notifications",
        )
      ).notifications,
    clear_notifications: (): Promise<{ message: string }> =>
      request("/api/admin/notifications", "DELETE"),
    read_notifications: (ids?: number[]): Promise<{ message: string }> =>
      request(
        "/api/admin/notifications/read",
        "POST",
        ids ? { ids } : undefined,
      ),

    clear_access_log: (): Promise<{ message: string }> =>
      request("/api/admin/access-log", "DELETE"),

    list_newsletter: async (): Promise<NewsletterEntry[]> =>
      (
        await request<{ newsletter: NewsletterEntry[] }>(
          "/api/admin/newsletter",
        )
      ).newsletter,
    create_newsletter: (body: NewsletterInput): Promise<NewsletterEntry> =>
      request("/api/admin/newsletter", "POST", body),
    update_newsletter: (
      id: number,
      body: NewsletterInput,
    ): Promise<NewsletterEntry> =>
      request(`/api/admin/newsletter/${id}`, "PATCH", body),
    delete_newsletter: (id: number): Promise<{ message: string }> =>
      request(`/api/admin/newsletter/${id}`, "DELETE"),

    blocked_words: (scope: string): Promise<BlockedWords> =>
      request(`/api/admin/blocked-words/${encodeURIComponent(scope)}`),
    set_blocked_words: (
      scope: string,
      body: { keywords?: string[]; patterns?: string[] },
    ): Promise<BlockedWords> =>
      request(
        `/api/admin/blocked-words/${encodeURIComponent(scope)}`,
        "PUT",
        body,
      ),

    webhooks: async (): Promise<Webhook[]> =>
      (await request<{ webhooks: Webhook[] }>("/api/admin/webhooks")).webhooks,
    events: async (): Promise<string[]> =>
      (await request<{ events: string[] }>("/api/admin/events")).events,
    create_webhook: (body: WebhookInput): Promise<Webhook> =>
      request("/api/admin/webhooks", "POST", body),
    update_webhook: (
      id: number,
      body: Partial<WebhookInput>,
    ): Promise<Webhook> => request(`/api/admin/webhooks/${id}`, "PATCH", body),
    delete_webhook: (id: number): Promise<{ message: string }> =>
      request(`/api/admin/webhooks/${id}`, "DELETE"),
    test_webhook: (
      id: number,
    ): Promise<{ status: string; code?: number; detail?: string }> =>
      request(`/api/admin/webhooks/${id}/test`, "POST"),
  },
};
