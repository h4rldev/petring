<script lang="ts">
 import { onMount } from 'svelte';
 import AdminCell from '$components/AdminCell.svelte';
 import { api } from '$lib/petring_api';

 const SCOPES = ['user_url', 'ad_url', 'global'] as const;
 type Scope = (typeof SCOPES)[number];

 let scope = $state<Scope>('user_url');
 let keywords = $state('');
 let patterns = $state('');
 let error = $state<string | null>(null);
 let notice = $state<string | null>(null);
 let busy = $state(false);

 onMount(load);

 async function load() {
   error = null;
   notice = null;
   try {
     const w = await api.admin.blocked_words(scope);
     keywords = w.keywords.join('\n');
     patterns = w.patterns.join('\n');
   } catch (e) {
     error = (e as Error).message;
   }
 }

 const lines = (s: string) => s.split('\n').map((x) => x.trim()).filter((x) => x !== '');

 async function save(ev: SubmitEvent) {
   ev.preventDefault();
   busy = true;
   error = null;
   notice = null;
   try {
     await api.admin.set_blocked_words(scope, { keywords: lines(keywords), patterns: lines(patterns) });
     notice = 'Saved.';
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }
</script>

<AdminCell name="blocked-words" title="Blocked words">
  {#if error}<p class="err">{error}</p>{/if}
  {#if notice}<p class="ok">{notice}</p>{/if}
  <form onsubmit={save}>
    <label class="field">
      <span>scope</span>
      <select bind:value={scope} onchange={load}>
        {#each SCOPES as s (s)}<option value={s}>{s}</option>{/each}
      </select>
    </label>
    <div class="panel">
      <label class="field"><span>keywords (one per line)</span><textarea bind:value={keywords} rows="8"></textarea></label>
      <label class="field"><span>patterns (regex, one per line)</span><textarea bind:value={patterns} rows="8"></textarea></label>
    </div>
    <div class="row"><button type="submit" disabled={busy}>Save</button></div>
  </form>
</AdminCell>

<style>
 @reference '$appcss';
 
 form {
   @apply flex flex-col gap-3;
 }

 .panel {
   @apply grid gap-4; grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr));
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

 .err {
   @apply text-(--color-error);
 }

 .ok {
   @apply text-(--color-confirm);
 }
</style>
