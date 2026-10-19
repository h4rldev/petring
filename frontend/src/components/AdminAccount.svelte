<script lang="ts">
 import { onMount } from 'svelte';
 import { api, type AccountInfo } from '$lib/petring_api';
 import { auth } from '$lib/auth.svelte';

 import AdminCell from '$components/AdminCell.svelte';

 const CREATE = '__create__';

 let accounts = $state<AccountInfo[]>([]);
 let selected = $state('');
 let username = $state('');
 let password = $state('');
 let notice = $state<string | null>(null);
 let error = $state<string | null>(null);
 let busy = $state(false);

 let s_username = $state('');
 let s_password = $state('');
 let s_notice = $state<string | null>(null);
 let s_error = $state<string | null>(null);

 const is_superadmin = $derived(auth.user?.role === 'superadmin');
 const others = $derived(accounts.filter((a) => a.username !== auth.user?.username));
 const editing = $derived(selected !== '' && selected !== CREATE);

 onMount(() => {
   s_username = auth.user?.username ?? '';
   load();
 });

 async function load() {
   try {
     accounts = await api.admin.accounts();
   } catch (e) {
     error = (e as Error).message;
   }
 }

 function pick() {
   password = '';
   notice = error = null;
   const a = accounts.find((x) => x.username === selected);
   username = a ? a.username : '';
 }

 async function save_self_username() {
   s_error = s_notice = null;
   try {
     await api.admin.change_username(auth.user!.username, s_username.trim());
     await auth.check();
     s_notice = 'Username updated.';
     await load();
   } catch (e) {
     s_error = (e as Error).message;
   }
 }

 async function save_self_password() {
   s_error = s_notice = null;
   if (!s_password) {
     s_error = 'Enter a new password.';
     return;
   }
   try {
     await api.admin.change_password(auth.user!.username, s_password);
     await auth.login(auth.user!.username, s_password);
     s_password = '';
     s_notice = 'Password updated.';
   } catch (e) {
     s_error = (e as Error).message;
   }
 }

 async function save() {
   busy = true;
   notice = error = null;
   try {
     if (selected === CREATE) {
       await api.admin.create_account(username.trim(), password, 'admin');
       notice = `Created ${username.trim()}.`;
     } else {
       if (username.trim() && username.trim() !== selected) {
         await api.admin.change_username(selected, username.trim());
       }
       if (password) await api.admin.change_password(selected, password);
       notice = `Updated ${username.trim() || selected}.`;
     }
     password = '';
     await load();
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }

 async function remove() {
   busy = true;
   notice = error = null;
   try {
     await api.admin.delete_account(selected);
     notice = `Deleted ${selected}.`;
     selected = '';
     username = '';
     password = '';
     await load();
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }
</script>

<AdminCell name="accounts" title="Accounts">
  <div class="panel" class:single={!is_superadmin}>
    <div class="col">
      <h3>Your account</h3>
      {#if s_error}<p class="err">{s_error}</p>{/if}
      {#if s_notice}<p class="ok">{s_notice}</p>{/if}
      <form onsubmit={(e) => { e.preventDefault(); save_self_username(); }}>
        <label class="field"><span>username</span><input bind:value={s_username} /></label>
        <button type="submit">Change username</button>
      </form>
      <form onsubmit={(e) => { e.preventDefault(); save_self_password(); }}>
        <label class="field"><span>new password</span><input type="password" bind:value={s_password} /></label>
        <button type="submit">Change password</button>
      </form>
    </div>

    {#if is_superadmin}
    <div class="col">
      <h3>Manage accounts</h3>
      {#if error}<p class="err">{error}</p>{/if}
      {#if notice}<p class="ok">{notice}</p>{/if}
      <label class="field">
        <span>account</span>
        <select bind:value={selected} onchange={pick}>
          <option value="">Select an account…</option>
          {#each others as a (a.username)}
            <option value={a.username}>{a.username} ({a.role})</option>
          {/each}
          {#if is_superadmin}
            <option value={CREATE}>Create new account</option>
          {/if}
        </select>
      </label>

      {#if editing || selected === CREATE}
        <form onsubmit={(e) => { e.preventDefault(); save(); }}>
          <label class="field"><span>username</span><input bind:value={username} /></label>
          <label class="field">
            <span>{selected === CREATE ? 'password' : 'new password'}</span>
            <input type="password" bind:value={password} />
          </label>
          <div class="row">
            <button type="submit" disabled={busy}>{selected === CREATE ? 'Create' : 'Save'}</button>
            {#if editing}
              <button type="button" class="danger" disabled={busy} onclick={remove}>Delete</button>
            {/if}
          </div>
        </form>
      {/if}
    </div>
    {/if}
  </div>
</AdminCell>

<style>
 @reference '$appcss';

 .panel {
   @apply grid gap-x-8 gap-y-6;
   grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr));
 }

 .panel.single {
   grid-template-columns: minmax(0, 26rem);
   justify-content: center;
 }

 h3 {
   @apply mb-3 text-base font-bold text-(--color-accent);
 }

 form {
   @apply mb-4 flex flex-col items-start gap-3;
 }

 .field {
   @apply flex w-full flex-col gap-1;
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
</style>
