<script lang="ts">
 import { onMount } from 'svelte';
 import { goto } from '$app/navigation';
 import { auth } from '$lib/auth.svelte';

 let username = $state('');
 let password = $state('');
 let error = $state<string | null>(null);
 let busy = $state(false);

 onMount(async () => {
   await auth.check();
   if (auth.user) goto('/admin/');
 });

 async function submit(e: SubmitEvent) {
   e.preventDefault();
   if (!username.trim() || !password) {
     error = 'Username and password are required.';
     return;
   }
   error = null;
   busy = true;
   try {
     await auth.login(username.trim(), password);
     goto('/admin/');
   } catch (err) {
     error = (err as Error).message;
   } finally {
     busy = false;
   }
 }
</script>

<section class="cell dither dither-corner card">
  <h1>Admin login</h1>
  <form onsubmit={submit}>
    <label class="field">
      <span>username</span>
      <input bind:value={username} autocomplete="username" />
    </label>
    <label class="field">
      <span>password</span>
      <input type="password" bind:value={password} autocomplete="current-password" />
    </label>
    {#if error}
      <p class="err">{error}</p>
    {/if}
    <button type="submit" disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</button>
  </form>
</section>

<style>
 @reference '$appcss';

 .card {
   @apply mx-auto mt-6 max-w-[26rem];
 }

 h1 {
   @apply mb-4 text-lg font-bold text-(--color-accent);
 }

 form {
   @apply flex flex-col gap-4;
 }

 .field {
   @apply flex flex-col gap-1;
 }

 .field span {
   @apply text-sm text-(--color-subtext);
 }

 .err {
   @apply text-(--color-error);
 }

 form button {
   @apply self-start;
 }
</style>
