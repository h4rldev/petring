<script lang="ts">
 import { onMount } from 'svelte';
 import { api, type Webhook, type WebhookInput } from '$lib/petring_api';
 import AdminCell from '$components/AdminCell.svelte';

 const FORMATS = ['generic', 'discord', 'slack'];

 let items = $state<Webhook[]>([]);
 let error = $state<string | null>(null);
 let notice = $state<string | null>(null);
 let busy = $state(false);

 let editing = $state<number | null>(null);
 let url = $state('');
 let format = $state<WebhookInput['format']>('generic');
 let events = $state('*');
 let enabled = $state(true);
 let known = $state<string[]>([]);

 onMount(() => {
   load();
   load_events();
 });

 async function load() {
   try {
     items = await api.admin.webhooks();
   } catch (e) {
     error = (e as Error).message;
   }
 }

 async function load_events() {
   try {
     known = await api.admin.events();
   } catch {}
 }
 
 function reset() {
   editing = null;
   url = '';
   format = 'generic';
   events = '*';
   enabled = true;
 }

 function edit(w: Webhook) {
   editing = w.id;
   url = w.url;
   format = w.format;
   events = w.events.join(', ');
   enabled = w.enabled;
 }

 const parse_events = (s: string) =>
   s.split(/[,\s]+/).map((x) => x.trim()).filter((x) => x !== '');

 async function save(ev: SubmitEvent) {
   ev.preventDefault();
   const list = parse_events(events);
   if (!url.trim() || list.length === 0) {
     error = 'Url and at least one event are required.';
     return;
   }
   busy = true;
   error = null;
   notice = null;
   try {
     const body = { url: url.trim(), format, events: list, enabled };
     if (editing === null) await api.admin.create_webhook(body);
     else await api.admin.update_webhook(editing, body);
     await load();
     reset();
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }

 async function toggle(w: Webhook) {
   busy = true;
   error = null;
   try {
     await api.admin.update_webhook(w.id, { enabled: !w.enabled });
     await load();
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }

 async function test(w: Webhook) {
   busy = true;
   error = null;
   notice = null;
   try {
     const r = await api.admin.test_webhook(w.id);
     notice = `Test ${w.url}: ${r.status}${r.code ? ` (${r.code})` : ''}${r.detail ? ` ${r.detail}` : ''}`;
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }

 async function remove(id: number) {
   busy = true;
   error = null;
   try {
     await api.admin.delete_webhook(id);
     if (editing === id) reset();
     await load();
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }
</script>

<AdminCell name="webhooks" title="Webhooks">
  {#if error}<p class="err">{error}</p>{/if}
  {#if notice}<p class="ok">{notice}</p>{/if}

  <form onsubmit={save}>
    <label class="field">
      <span>url</span>
      <input bind:value={url} placeholder="https://..." />
    </label>
    <div class="panel">
      <label class="field">
        <span>format</span>
        <select bind:value={format}>
          {#each FORMATS as f (f)}
            <option value={f}>{f}</option>
          {/each}
        </select>
      </label>
      <label class="field">
        <span>events (comma separated, * for all)</span>
        <input bind:value={events} list="webhook-events" />
        <datalist id="webhook-events">
          <option value="*"></option>
          {#each known as e (e)}
            <option value={e}></option>
          {/each}
        </datalist>
        <span class="hint">{known.length ? `known: ${known.join(', ')}` : 'no events seen yet'}</span>
      </label>
    </div>
    {#if editing !== null}
      <label class="check">
        <input type="checkbox" bind:checked={enabled} />
        enabled
      </label>
    {/if}
    <div class="row">
      <button type="submit" disabled={busy}>{editing === null ? 'Add webhook' : 'Save'}</button>
      {#if editing !== null}
        <button type="button" disabled={busy} onclick={reset}>Cancel</button>
      {/if}
    </div>
  </form>

  {#if items.length === 0}
    <p class="muted">No webhooks yet.</p>
  {:else}
    <ul class="items">
      {#each items as w (w.id)}
        <li>
          <div class="who">
            <span class="url">{w.url}</span>
            <span class="format">{w.format}</span>
            <span class="events">{w.events.join(', ')}</span>
            {#if !w.enabled}<span class="off">disabled</span>{/if}
            {#if w.secret}<span class="secret" title={w.secret}>sig {w.secret.slice(0, 10)}…</span>{/if}
            {#if w.last_delivered_at}
              <span class={w.last_status && w.last_status < 400 ? 'ok' : 'off'}>
                last {w.last_status ?? 'err'} · {new Date(w.last_delivered_at * 1000).toLocaleString('en', { dateStyle: 'short', timeStyle: 'short' })}
              </span>
            {/if}
          </div>
          <div class="row">
            <button type="button" disabled={busy} onclick={() => test(w)}>Test</button>
            <button type="button" disabled={busy} onclick={() => edit(w)}>Edit</button>
            <button type="button" disabled={busy} onclick={() => toggle(w)}>{w.enabled ? 'Disable' : 'Enable'}</button>
            <button type="button" class="danger" disabled={busy} onclick={() => remove(w.id)}>Delete</button>
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</AdminCell>

<style>
 @reference '$appcss';

 form {
   @apply mb-5 flex flex-col gap-3;
 }

 .panel {
   @apply grid gap-3;
   grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr));
 }

 .field {
   @apply flex flex-col gap-1;
 }

 .field span {
   @apply text-sm text-(--color-subtext);
 }

 .check {
   @apply flex items-center gap-2 text-sm text-(--color-subtext);
 }

 .row {
   @apply flex shrink-0 flex-wrap gap-2;
 }

 .items {
   @apply flex flex-col gap-3;
 }

 .items li {
   @apply flex items-start justify-between gap-4;
 }

 .who {
   @apply min-w-0 text-[.9rem];
 }

 .format {
   @apply ml-2 text-xs uppercase tracking-[.05em] text-(--color-subtext-2);
 }

 .events {
   @apply ml-2 text-xs text-(--color-subtext);
 }

 .off {
   @apply ml-2 text-xs text-(--color-warning);
 }

 .secret {
   @apply ml-2 font-mono text-xs text-(--color-subtext-2);
 }

 .danger {
   @apply text-(--color-error);
 }

 .muted {
   @apply text-(--color-subtext);
 }

 .err {
   @apply break-all text-(--color-error);
 }

 .ok {
   @apply break-all text-(--color-confirm);
 }

 .url {
   @apply break-all;
 }
</style>
