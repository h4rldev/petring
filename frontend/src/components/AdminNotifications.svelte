<script lang="ts">
 import { onMount } from 'svelte';
 import { api, type Notification } from '$lib/petring_api';

 import AdminCell from '$components/AdminCell.svelte';
 
 let items = $state<Notification[]>([]);
 let error = $state<string | null>(null);
 let busy = $state(false);
 let socket: WebSocket | null = null;
 let filter = $state('all');

 const kinds = $derived(['all', ...new Set(items.map((n) => n.kind))]);
 const shown = $derived(filter === 'all' ? items : items.filter((n) => n.kind === filter));
 const unread = $derived(items.filter((n) => !n.read).length);
 
 const fmt = (s: number) =>
   new Date(s * 1000).toLocaleString('en', { dateStyle: 'short', timeStyle: 'short' });

 onMount(() => {
   load();
   const proto = location.protocol === 'https:' ? 'wss' : 'ws';
   socket = new WebSocket(`${proto}://${location.host}/api/admin/notifications/ws`);
   socket.onmessage = (ev) => {
     try {
       items = [JSON.parse(ev.data) as Notification, ...items];
     } catch {}
   };
   return () => socket?.close();
 });

 async function load() {
   try {
     items = await api.admin.notifications();
   } catch (e) {
     error = (e as Error).message;
   }
 }

 async function clear() {
   busy = true;
   error = null;
   try {
     await api.admin.clear_notifications();
     items = [];
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }

 async function mark_all() {
   busy = true;
   error = null;
   try {
     await api.admin.read_notifications();
     items = items.map((n) => ({ ...n, read: true }));
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }

 async function mark(n: Notification) {
   if (n.read || n.id === undefined) return;
   try {
     await api.admin.read_notifications([n.id]);
     items = items.map((x) => (x.id === n.id ? { ...x, read: true } : x));
   } catch {}
 }
 
</script>

<AdminCell name="notifications" title={`Notifications (${unread} new)`}>
  <div class="tools">
    <select bind:value={filter}>
      {#each kinds as k (k)}<option value={k}>{k}</option>{/each}
    </select>
    <button type="button" disabled={busy || unread === 0} onclick={mark_all}>Mark all read</button>
    <button type="button" disabled={busy || items.length === 0} onclick={clear}>Clear</button>
  </div>
  {#if error}<p class="err">{error}</p>{/if}
  {#if shown.length === 0}
    <p class="muted">Nothing yet.</p>
  {:else}
    <ul class="items">
      {#each shown as n, i (n.id ?? i)}
        <li class={n.read ? '' : 'unread'}>
          <button type="button" class="mark" onclick={() => mark(n)}>
            <span class="who">
              <span class="kind">{n.kind}.{n.action}</span>
              <span>{n.content}</span>
            </span>
            <span class="time">{fmt(n.created_at)}</span>
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</AdminCell>

<style>
 @reference '$appcss';

 .tools {
   @apply mb-3 flex flex-wrap items-center justify-end gap-2;
 }

 .tools select {
   @apply mr-auto w-auto min-w-[7rem] pr-6;
 }

 .tools button {
   @apply whitespace-nowrap;
 }
 
 .items {
   @apply flex flex-col gap-2;
 }

 .items li {
   @apply border-b border-(--color-surface-2) pb-2;
 }

 .mark {
   @apply flex h-auto w-full items-center justify-between gap-4 border-0 bg-transparent px-0 py-0 text-left text-[.9rem] leading-normal tracking-normal;
 }

 .mark:hover {
   @apply bg-transparent;
 }

 .items li.unread .mark:hover {
   @apply text-(--color-accent);
 }

 .items li.unread .mark {
   @apply font-semibold;
 }

 .kind {
   @apply mr-2 text-xs text-(--color-warning);
 }

 .time {
   @apply shrink-0 text-xs text-(--color-subtext-2);
 }

 .muted {
   @apply text-(--color-subtext);
 }
</style>
