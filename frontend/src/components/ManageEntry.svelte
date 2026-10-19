<script lang="ts">
 import { onMount } from 'svelte';
 import { goto } from '$app/navigation';
 import { api, get_manage_token, set_manage_token } from '$lib/petring_api';

 let token = $state('');
 let error = $state<string | null>(null);
 let remember = $state<boolean>(false);
 let busy = $state(false);

 onMount(() => {
   token = get_manage_token() ?? '';
 });

 async function submit(e: SubmitEvent) {
   e.preventDefault();
   const t = token.trim();
   if (!t) {
     error = 'Enter your manage token.';
     return;
   }
   error = null;
   busy = true;
   try {
     await api.manage.get(t);
   } catch (err) {
     error = (err as Error).message;
     busy = false;
     return;
   }
   set_manage_token(t, remember);
   goto('/manage/');
 }
</script>

<form onsubmit={submit}>
  <label class="field">
    <span>manage token</span>
    <input bind:value={token} placeholder="paste your token" autocomplete="off" spellcheck="false" />
  </label>
  {#if error}
    <p class="err">{error}</p>
  {/if}
  <label class="remember"><input type="checkbox" bind:checked={remember}> remember this browser</label>
  <button type="submit" disabled={busy}>{busy ? 'Checking…' : 'Manage my entry'}</button>
</form>

<style>
 @reference '$appcss';

 form {
   @apply flex max-w-[24rem] flex-col gap-4;
 }

 .field {
   @apply flex flex-col gap-1;
 }

 .field span {
   @apply text-sm text-(--color-subtext);
 }

 .remember {
   @apply flex items-center gap-2 text-sm text-(--color-subtext);
 }
</style>
