<script lang="ts">
 import { onMount } from 'svelte';
 import { api, type ManagedUser, type ManagedAd } from '$lib/petring_api';

 import AdminCell from '$components/AdminCell.svelte';

 const CREATE = '__create__';
 const PAGE = 20;

 let query = $state('');
 let results = $state<ManagedUser[]>([]);
 let total = $state(0);

 let selected = $state('');
 let selected_user = $state<ManagedUser | null>(null);
 let current_ad = $state<ManagedAd | null>(null);

 let error = $state<string | null>(null);
 let notice = $state<string | null>(null);
 let busy = $state(false);

 let m_username = $state('');
 let m_url = $state('');
 let m_contact = $state('');

 let a_image = $state('');
 let a_url = $state('');

 let typing: ReturnType<typeof setTimeout> | undefined;

 const fmt_ts = (s: number | null) =>
   s ? new Date(s * 1000).toLocaleString('en', { dateStyle: 'short', timeStyle: 'short' }) : 'never';

 onMount(search);

 function on_search() {
   clearTimeout(typing);
   typing = setTimeout(search, 250);
 }

 async function search() {
   try {
     const { users, total: t } = await api.admin.all_users({ q: query.trim(), limit: PAGE });
     results = users;
     total = t;
   } catch (e) {
     error = (e as Error).message;
   }
 }

 async function pick(name: string) {
   if (name === selected && name !== CREATE) {
     selected = '';
     selected_user = '';
     current_ad = null;
     error = null;
     notice = null;
     return;
   }
   
   selected = name;
   error = null;
   notice = null;

   if (name === CREATE) {
     selected_user = null;
     current_ad = null;
     m_username = '';
     m_url = '';
     m_contact = '';
     a_image = '';
     a_url = '';
     return;
   }
   
   const u = results.find((u) => u.username === name) ?? null;
   selected_user = u;
   m_username = u?.username ?? '';
   m_url = u?.url ?? '';
   m_contact = u?.contact ?? '';
   await load_ad(name);
 }

 async function load_ad(name: string) {
   if (!name || name === CREATE) {
     current_ad = null;
     a_image = '';
     a_url = '';
     return;
   }

   try {
     const { ads } = await api.admin.all_ads({ q: name, limit: 1 });
     current_ad = ads.find((a) => a.username === name) ?? null;
     a_image = current_ad?.image_url ?? '';
     a_url = current_ad?.ad_url ?? '';
   } catch (e) {
     error = (e as Error).message;
   }
 }

 async function save_member(ev: SubmitEvent) {
   ev.preventDefault();
   busy = true;
   error = null;
   notice = null;

   try {
     if (selected === CREATE) {
       const name = m_username.trim();
       const { user, manage_token } = await api.admin.create_user({
         username: name,
         url: m_url.trim(),
         contact: m_contact,
         verified: true,
       });

       await search();
       await pick(user.username);
       notice = `Member created. Manage token (shown once): ${manage_token}`;
     } else {
       selected_user = await api.admin.update_user(selected, {
         url: m_url.trim(),
         contact: m_contact,
       });
     }
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }

 async function reset_token() {
   busy = true;
   error = null;
   notice = null;

   try {
     const { manage_token } = await api.admin.regenerate_token(selected);
     const { users } = await api.admin.all_users({ q: selected, limit: 1 });
     selected_user = users.find((u) => u.username === selected) ?? selected_user;
     notice = `New manage token (shown once): ${manage_token}`;
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }

 async function delete_member() {
   busy = true;
   error = null;
   notice = null;

   try {
     await api.admin.delete_user(selected);
     selected = '';
     selected_user = null;
     current_ad = null;
     await search();
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }

 async function save_ad(ev: SubmitEvent) {
   ev.preventDefault();
   busy = true;
   error = null;
   notice = null;

   try {
     if (current_ad) await api.admin.update_ad(selected, { image_url: a_image.trim(), ad_url: a_url.trim() });
     else await api.admin.create_ad({ username: selected, image_url: a_image.trim() });
     await load_ad(selected);
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }

 async function delete_ad() {
   busy = true;
   error = null;
   notice = null;

   try {
     await api.admin.delete_ad(selected);
     await load_ad(selected);
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }
</script>

<AdminCell name="members" title="Members and Ads">
  {#if error}<p class="err">{error}</p>{/if}
  {#if notice}<p class="ok">{notice}</p>{/if}

  <div class="search">
    <input aria-label="search members" bind:value={query} oninput={on_search} placeholder="search username or url" />
    <button type="button" onclick={() => pick(CREATE)}>+ New member</button>
    <span class="count">{results.length} of {total}</span>
  </div>

  <div class="matches">
    {#each results as u (u.id)}
      <button type="button" class={selected === u.username ? 'match sel' : 'match'} onclick={() => pick(u.username)}>
        {u.username}{#if !u.verified}<span class="tag">unverified</span>{/if}
      </button>
     {:else}
      <p class="muted">No matches.</p>
    {/each}
  </div>

  {#if selected}
    <div class="panel">
      <div class="col">
        <h3>Member</h3>
        <form onsubmit={save_member}>
          <label class="field"><span>username</span><input bind:value={m_username} disabled={selected !== CREATE} /></label>
          <label class="field"><span>url</span><input bind:value={m_url} /></label>
          <label class="field"><span>contact</span><input bind:value={m_contact} /></label>
          <div class="row">
            <button type="submit" disabled={busy}>{selected === CREATE ? 'Create' : 'Save'}</button>
            {#if selected !== CREATE}
              <button type="button" disabled={busy} onclick={reset_token}>Reset token</button>
              <button type="button" class="danger" disabled={busy} onclick={delete_member}>Delete</button>
            {/if}
          </div>
        </form>
        {#if selected_user}
          <p class="muted">
            Token created {fmt_ts(selected_user.manage_token_created_at)} · last used {fmt_ts(selected_user.manage_token_last_used_at)}
          </p>
        {/if}
      </div>

      <div class="col">
        <h3>Ad</h3>
        {#if selected === CREATE}
          <p class="muted">Save the member first, then add an ad.</p>
        {:else}
          <form onsubmit={save_ad}>
            <label class="field"><span>image url</span><input bind:value={a_image} /></label>
            <label class="field"><span>ad url</span><input bind:value={a_url} disabled={!current_ad} /></label>
            <div class="row">
              <button type="submit" disabled={busy}>{current_ad ? 'Save' : 'Create ad'}</button>
              {#if current_ad}
                <button type="button" class="danger" disabled={busy} onclick={delete_ad}>Delete ad</button>
              {/if}
            </div>
          </form>
        {/if}
      </div>
    </div>
  {/if}
</AdminCell>

<style>
 @reference '$appcss';

 h3 {
   @apply text-sm font-bold text-(--color-accent);
 }

 .search {
   @apply mx-auto mb-2 flex w-full max-w-[36rem] items-center gap-2;
 }

 .search input {
   @apply flex-1;
 }

 .search .count {
   @apply shrink-0 text-xs text-(--color-subtext);
 }

 .matches {
   @apply mx-auto mb-5 flex max-h-[15rem] w-full max-w-[36rem] flex-col overflow-y-auto border-2 border-(--color-surface-2) bg-(--color-bg);
   border-style: inset;
 }

 .matches .muted {
   @apply px-3 py-2;
 }

 .match {
   @apply flex h-auto w-full items-center justify-start gap-2 border-0 bg-transparent px-3 py-1 text-left text-[.9rem] font-normal normal-case tracking-normal;
 }

 .match:hover {
   @apply bg-(--color-secondary) text-(--color-text);
 }

 .match.sel {
   @apply bg-(--color-accent) text-(--color-on-accent);
 }

 .match.sel .tag {
   @apply text-(--color-on-accent);
 }

 .tag {
   @apply ml-1 text-xs text-(--color-warning);
 }

 .panel {
   @apply grid gap-6;
   grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr));
 }

 .col {
   @apply flex flex-col gap-3;
 }

 form {
   @apply flex flex-col gap-3;
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

 .muted {
   @apply text-(--color-subtext);
 }

 .err {
   @apply text-(--color-error);
 }

 .ok {
   @apply text-(--color-confirm);
 }
</style>
