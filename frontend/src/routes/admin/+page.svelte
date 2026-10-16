<script lang="ts">
 import { onMount } from 'svelte';
 import { goto } from '$app/navigation';
 import { api, type ManagedUser, type ManagedAd } from '$lib/petring_api';
 import { auth } from '$lib/auth.svelte';
 
 import AdminCell from '$components/AdminCell.svelte';
 import AdminNotifications from '$components/AdminNotifications.svelte';
 import AdminNewsletter from '$components/AdminNewsletter.svelte';
 import AdminWebhooks from '$components/AdminWebhooks.svelte';
 import AdminAccount from '$components/AdminAccount.svelte';
 import AdminMembers from '$components/AdminMembers.svelte';
 import AdminBlockedWords from '$components/AdminBlockedWords.svelte';

 let users = $state<ManagedUser[]>([]);
 let ads = $state<ManagedAd[]>([]);
 let loading = $state(true);
 let error = $state<string | null>(null);
 let busy = $state<string | null>(null);
 let member_count = $state(0);
 let ad_count = $state(0);

 const num = (n?: number) =>
   (n ?? 0).toLocaleString('en');
 
 async function load() {
   loading = true;
   error = null;
   try {
     const [u, a, stats] = await Promise.all([
       api.admin.unverified_users(),
       api.admin.unverified_ads(),
       api.stats(),
     ]);
     users = u;
     ads = a;
     member_count = stats.members;
     ad_count = stats.ads;
   } catch (e) {
     error = (e as Error).message;
   } finally {
     loading = false;
   }
 }

 async function act(key: string, fn: () => Promise<unknown>) {
   busy = key;
   error = null;
   try {
     await fn();
     await load();
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = null;
   }
 }

 async function logout() {
   await auth.logout();
   goto('/');
 }

 onMount(async () => {
   await auth.check();
   if (!auth.user) {
     goto('/login/');
     return;
   }
   await load();
 });
</script>

{#if loading}
  <p class="muted">Loading…</p>
{:else}
  {#if error}<p class="err">{error}</p>{/if}
  <section class="cell dither dither-corner welcome">
    <div class="welcome-top">
      <p class="whoami">
        Signed in as <strong>{auth.user?.username}</strong>
        <span class="role">{auth.user?.role}</span>
      </p>
      <button type="button" class="forget" onclick={logout}>Sign out</button>
    </div>
    <div class="stats">
      <div class="stat"><span class="num">{num(member_count)}</span><span class="label">members</span></div>
      <div class="stat"><span class="num">{num(ad_count)}</span><span class="label">ads</span></div>
    </div>
  </section>


  
  <AdminCell name="pending-users" title={`Pending users (${users.length})`}>
    {#if users.length === 0}
      <p class="muted">Nothing waiting.</p>
    {:else}
      <ul class="items">
        {#each users as u (u.id)}
          <li>
            <div class="who">
              <a href={u.url} target="_blank" rel="noopener">{u.username}</a>
              {#if u.contact}<span class="contact">{u.contact}</span>{/if}
            </div>
            <div class="row">
              <button type="button" disabled={busy !== null}
                      onclick={() => act('vu:' + u.username, () => api.admin.verify_user(u.username))}>
                Verify
              </button>
              <button type="button" class="danger" disabled={busy !== null}
                      onclick={() => act('du:' + u.username, () => api.admin.delete_user(u.username))}>
                Delete
              </button>
            </div>
          </li>
        {/each}
      </ul>
    {/if}
  </AdminCell>

  <AdminCell name="pending-ads" title={`Pending ads (${ads.length})`}>
    {#if ads.length === 0}
      <p class="muted">Nothing waiting.</p>
    {:else}
      <ul class="items">
        {#each ads as a (a.id)}
          <li>
            <a class="ad" href={a.ad_url} target="_blank" rel="noopener">
              <img src={a.image_url} alt={`ad for ${a.username}`} />
            </a>
            <div class="row">
              <button type="button" disabled={busy !== null}
                      onclick={() => act('va:' + a.username, () => api.admin.verify_ad(a.username))}>
                Verify
              </button>
              <button type="button" class="danger" disabled={busy !== null}
                      onclick={() => act('da:' + a.username, () => api.admin.delete_ad(a.username))}>
                Delete
              </button>
            </div>
          </li>
        {/each}
      </ul>
    {/if}
  </AdminCell>

  <AdminNotifications />
  <AdminNewsletter />
  <AdminAccount />
  <AdminMembers />
  <AdminWebhooks />
  <AdminBlockedWords />
{/if}

<style>
 @reference '$appcss';

 section {
   @apply mb-5;
 }

 .items {
   @apply flex flex-col gap-3;
 }

 .items li {
   @apply flex items-center justify-between gap-4;
 }

 .who {
   @apply text-[.9rem];
 }

 .contact {
   @apply ml-2 text-xs text-(--color-subtext);
 }

 .row {
   @apply flex flex-wrap gap-2;
 }

 .danger {
   @apply text-(--color-error);
 }

 .ad {
   @apply inline-block border-2 border-(--color-surface-2);
 }

 .ad img {
   @apply block h-[2rem] w-auto;
 }

 .muted {
   @apply text-(--color-subtext);
 }

 .err {
   @apply text-(--color-error);
 }

 .welcome-top {
   @apply mb-4 flex flex-wrap items-center justify-between gap-4;
 }

 .whoami {
   @apply text-[.9rem] text-(--color-subtext);
 }

 .whoami strong {
   @apply text-(--color-text);
 }

 .role {
   @apply ml-2 text-xs uppercase tracking-[.05em] text-(--color-subtext-2);
 }

 .stats {
   @apply grid gap-4;
   grid-template-columns: repeat(auto-fit, minmax(8rem, 1fr));
 }

 .stat {
   @apply flex flex-col items-center text-center;
 }

 .num {
   @apply text-2xl font-bold text-(--color-accent);
 }

 .label {
   @apply text-sm text-(--color-subtext);
 }

 .forget {
   @apply text-[.85rem];
 }
</style>
