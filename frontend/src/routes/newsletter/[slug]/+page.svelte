<script lang="ts">
 import { page } from '$app/state';
 import { goto } from '$app/navigation';
 import RichMarkdown from '$components/RichMarkdown.svelte';
 import { api, type NewsletterEntry } from '$lib/petring_api';
 import { auth } from '$lib/auth.svelte';

 let entry = $state<NewsletterEntry | null>(null);
 let error = $state<string | null>(null);
 let busy = $state(false);
 const slug = $derived(page.params.slug);

 const fmt = (s: number) =>
   new Date(s * 1000).toLocaleDateString('en', { year: 'numeric', month: 'short', day: 'numeric' });

 async function remove() {
   if (!entry || !confirm('Delete this post?')) return;
   busy = true;
   try {
     await api.admin.delete_newsletter(entry.id);
     goto('/newsletter/');
   } catch (e) {
     error = (e as Error).message;
     busy = false;
   }
 }

 $effect(() => {
   const s = slug;
   if (!s) return;
   api.get_newsletter_entry(s).then((e) => (entry = e)).catch((e) => (error = e.message));
 });
</script>

<svelte:head>
  <title>{entry?.title ?? 'Newsletter'} - petRing</title>
  <link rel="canonical" href={`https://webring.pet/newsletter/${slug}/`} />
  <meta property="og:title" content={entry?.title ?? 'Newsletter - petRing'} />
</svelte:head>

<a class="back" href="/newsletter/">&lt;- all entries</a>

{#if error}
  <p class="err">{error}</p>
{:else if entry}
   <article class="cell dither dither-corner">
    <div class="head">
      <h1>{entry.title}</h1>
      {#if auth.user}
        <div class="admin-row">
          <a class="button" href={`/admin/?edit=${entry.id}`}>edit</a>
          <button type="button" class="danger" disabled={busy} onclick={remove}>delete</button>
        </div>
      {/if}
    </div>
    <p class="date">
      {fmt(entry.posted_at)}{entry.authors.length ? ` · by ${entry.authors.join(', ')}` : ''}{entry.edited_at
        ? ` · edited ${fmt(entry.edited_at)}`
        : ''}
    </p>
    <RichMarkdown md={entry.content_markdown} />
  </article>
{:else}
  <p class="muted">Loading…</p>
{/if}

<style>
  @reference '$appcss';

  .back {
    @apply text-[.85rem] text-(--color-link) no-underline;
  }

  .back:hover {
    @apply text-(--color-accent);
  }

  .err {
    @apply text-(--color-error);
  }

  .muted {
    @apply text-(--color-subtext);
  }

  h1 {
    @apply mb-1 text-2xl font-bold text-(--color-accent);
  }

  .date {
    @apply mb-4 text-xs text-(--color-subtext-2);
  }

  .head {
    @apply mb-1 flex items-center justify-between gap-3;
  }

  .admin-row {
    @apply flex flex-wrap gap-2;
  }

  .danger {
    @apply text-(--color-error);
  }
</style>
