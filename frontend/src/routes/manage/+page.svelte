<script lang="ts">
  import { onMount } from 'svelte';
  import {
    api,
    get_manage_token,
    clear_manage_token,
    type ManagedUser,
    type ManagedAd,
  } from '$lib/petring_api';

  let token = $state('');
  let user = $state<ManagedUser | null>(null);
  let ad = $state<ManagedAd | null>(null);
  let loading = $state(true);
  let error = $state<string | null>(null);

  let url = $state('');
  let contact = $state('');
  let image_url = $state('');

  let ring_msg = $state<string | null>(null);
  let ad_msg = $state<string | null>(null);
  let ring_ok = $state(false);
  let ad_ok = $state(false);
  let ring_busy = $state(false);
  let ad_busy = $state(false);

  onMount(async () => {
    token = get_manage_token();
    if (!token) {
      loading = false;
      return;
    }
    try {
      const u = await api.manage.get(token);
      user = u;
      url = u.url;
      contact = u.contact;
      try {
        const a = await api.manage.get_ad(token);
        ad = a;
        image_url = a.image_url;
      } catch {
        ad = null;
      }
    } catch (e) {
      error = (e as Error).message;
    } finally {
      loading = false;
    }
  });

  async function save_ring(e: SubmitEvent) {
    e.preventDefault();
    ring_busy = true;
    ring_msg = null;
    try {
      const u = await api.manage.update(token, {
        url: url.trim(),
        contact: contact.trim(),
      });
      if (u) {
        user = u;
        url = u.url;
        contact = u.contact;
        ring_msg = 'Saved.';
        ring_ok = true;
      } else {
        ring_msg = 'No changes to save.';
        ring_ok = true;
      }
    } catch (e) {
      ring_msg = (e as Error).message;
      ring_ok = false;
    } finally {
      ring_busy = false;
    }
  }

  async function delete_ring() {
    if (!confirm('Delete your ring entry? This cannot be undone.')) return;
    ring_busy = true;
    ring_msg = null;
    try {
      await api.manage.remove(token);
      clear_manage_token();
      token = '';
    } catch (e) {
      ring_msg = (e as Error).message;
      ring_ok = false;
    } finally {
      ring_busy = false;
    }
  }

  async function save_ad(e: SubmitEvent) {
    e.preventDefault();
    ad_busy = true;
    ad_msg = null;
    try {
      const a = ad
        ? await api.manage.update_ad(token, image_url.trim())
        : await api.manage.create_ad(token, image_url.trim());
      if (a) {
        ad = a;
        image_url = a.image_url;
        ad_msg = 'Saved.';
        ad_ok = true;
      } else {
        ad_msg = 'No changes to save.';
        ad_ok = true;
      }
    } catch (e) {
      ad_msg = (e as Error).message;
      ad_ok = false;
    } finally {
      ad_busy = false;
    }
  }

  async function delete_ad() {
    if (!confirm('Delete your ad?')) return;
    ad_busy = true;
    ad_msg = null;
    try {
      await api.manage.remove_ad(token);
      ad = null;
      image_url = '';
      ad_msg = 'Ad deleted.';
      ad_ok = true;
    } catch (e) {
      ad_msg = (e as Error).message;
      ad_ok = false;
    } finally {
      ad_busy = false;
    }
  }

  function forget() {
    clear_manage_token();
    token = '';
    user = null;
    ad = null;
  }
</script>

{#if loading}
  <p class="muted">Loading…</p>
{:else if !token}
  <section class="cell dither dither-corner">
    <h2>No token</h2>
    <p class="muted">
      Paste your manage token on the <a href="/">home page</a> to manage your entry.
    </p>
  </section>
{:else if error}
  <section class="cell dither dither-corner">
    <h2>Invalid token</h2>
    <p class="err">{error}</p>
    <button type="button" onclick={forget}>Forget token</button>
  </section>
{:else if user}
  <section class="cell dither dither-corner">
    <div class="head">
      <h2>Your ring entry</h2>
      <button type="button" class="forget" onclick={forget}>Forget token in this browser</button>
    </div>
    <p class="who">
      <span class="name">{user.username}</span>
      <span class="status" class:ok={user.verified} class:warn={!user.verified}>
        {user.verified ? 'verified' : 'pending verification'}
      </span>
    </p>
    <form onsubmit={save_ring}>
      <label class="field">
        <span>url</span>
        <input bind:value={url} type="url" placeholder="https://your-site.example" />
      </label>
      <label class="field">
        <span>contact</span>
        <textarea bind:value={contact} rows="3" placeholder="how to reach you (optional)"></textarea>
      </label>
      <div class="row">
        <button type="submit" disabled={ring_busy}>{ring_busy ? 'Saving…' : 'Save entry'}</button>
        <button type="button" class="danger" onclick={delete_ring} disabled={ring_busy}>Delete entry</button>
      </div>
      {#if ring_msg}<p class={ring_ok ? 'note' : 'err'}>{ring_msg}</p>{/if}
    </form>
  </section>

  <section class="cell dither dither-corner">
    <h2>Your ad</h2>
    {#if ad}
      <a class="ad" href={ad.ad_url}>
        <img src={ad.image_url} alt={`ad for ${ad.username}`} />
      </a>
      <p class="who">
        <span class="status" class:ok={ad.verified} class:warn={!ad.verified}>
          {ad.verified ? 'verified' : 'pending verification'}
        </span>
      </p>
    {:else}
      <p class="muted">No ad yet, add one below.</p>
    {/if}
    <form onsubmit={save_ad}>
      <label class="field">
        <span>image url</span>
        <input bind:value={image_url} type="url" required placeholder="https://example.com/ad.png" />
      </label>
      <div class="row">
        <button type="submit" disabled={ad_busy}>
          {ad_busy ? 'Saving…' : ad ? 'Save ad' : 'Submit ad'}
        </button>
        {#if ad}
          <button type="button" class="danger" onclick={delete_ad} disabled={ad_busy}>Delete ad</button>
        {/if}
      </div>
      {#if ad_msg}<p class={ad_ok ? 'note' : 'err'}>{ad_msg}</p>{/if}
    </form>
  </section>
{/if}

<style>
  @reference '$appcss';

  h2 {
    @apply mb-3 text-base font-bold text-(--color-accent);
  }

  .head {
    @apply mb-4 flex items-center justify-between gap-4;
  }

  .head h2 {
    @apply mb-0;
  }

  form {
    @apply flex max-w-[32rem] flex-col gap-4;
  }

  .field {
    @apply flex flex-col gap-1;
  }

  .field span {
    @apply text-sm text-(--color-subtext);
  }

  .row {
    @apply flex flex-wrap gap-2;
  }

  .danger {
    @apply text-(--color-error);
  }

   .who {
    @apply mb-4 flex items-baseline gap-3;
  }

  .name {
    @apply text-lg font-bold text-(--color-text);
  }

  .status {
    @apply text-sm;
  }

  .status.ok {
    @apply text-(--color-confirm);
  }

  .status.warn {
    @apply text-(--color-warning);
  }

  .ad {
    @apply mb-3 inline-block border-2 border-(--color-surface-2);
  }

  .ad img {
    @apply block;
  }

  .note {
    @apply text-(--color-confirm);
  }

  .muted {
    @apply text-(--color-subtext);
  }

  .err {
    @apply text-(--color-error);
  }

  .forget {
    @apply shrink-0 text-[.85rem];
  }
</style>
