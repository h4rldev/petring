<script lang="ts">
 import { api } from '$lib/petring_api';

 let username = $state('');
 let url = $state('');
 let contact = $state('');
 let busy = $state(false);
 let error = $state<string | null>(null);
 let token = $state<string | null>(null);
 let copied = $state(false);

 async function submit(e: SubmitEvent) {
   e.preventDefault();
   busy = true;
   error = null;
   try {
     const res = await api.create_user(username.trim(), url.trim(), contact.trim());
     token = res.manage_token;
   } catch (err) {
     error = (err as Error).message;
   } finally {
     busy = false;
   }
 }

 async function copy() {
   if (!token) return;
   await navigator.clipboard.writeText(token);
   copied = true;
   setTimeout(() => (copied = false), 1500);
 }
</script>

{#if token}
 <div>
   <p class="warn">Save this token now, as it is shown only once. It lets you edit or remove your entry later.</p>
   <div class="token-row">
     <code class="token">{token}</code>
     <button type="button" onclick={copy}>{copied ? 'Copied!' : 'Copy'}</button>
   </div>
 </div>
{:else}
 <form onsubmit={submit}>
   <label class="field">
     <span>username</span>
     <input bind:value={username} required maxlength="32" placeholder="your name" />
   </label>
   <label class="field">
     <span>url</span>
     <input bind:value={url} type="url" required placeholder="https://your-site.example" />
   </label>
   <label class="field">
     <span>contact</span>
     <textarea bind:value={contact} rows="3" placeholder="how to reach you (optional)"></textarea>
   </label>
   {#if error}
     <p class="err">{error}</p>
   {/if}
   <button type="submit" disabled={busy} class="go">{busy ? 'Submitting…' : 'Join the ring'}</button>
 </form>
{/if}

<style>
 @reference '$appcss';

 form {
   @apply flex max-w-[32rem] flex-col gap-4;
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

 .go {
   @apply self-start;
 }

 .go:disabled {
   @apply cursor-default opacity-60;
 }

 .warn {
   @apply mb-2 text-(--color-warning);
 }

 .token-row {
   @apply flex flex-wrap items-center gap-2;
 }

 .token {
   @apply border-2 border-(--color-surface-2) bg-(--color-bg) px-3 py-2;
   border-style: inset;
   word-break: break-all;
 }
</style>
