<script lang="ts">
 import RichMarkdown from '$components/RichMarkdown.svelte';
 import { api, type NewsletterEntry } from '$lib/petring_api';
 import { excerpt } from '$lib/markdown';
 import { auth } from '$lib/auth.svelte';

 let newsletter = $state<NewsletterEntry[]>([]);
 let error = $state<string | null>(null);
 let loading = $state(true);
 let busy = $state<number | null>(null);

 const fmt = (s: number) =>
   new Date(s * 1000).toLocaleDateString('en', { year: 'numeric', month: 'short', day: 'numeric' });

 $effect(() => {
   api
     .get_newsletter()
     .then((n) => (newsletter = n))
     .catch((e) => (error = e.message))
     .finally(() => (loading = false));
 });

 async function remove(id: number) {
   if (!confirm('Delete this post?')) return;
   busy = id;
   try {
     await api.admin.delete_newsletter(id);
     newsletter = newsletter.filter((e) => e.id !== id);
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = null;
   }
 }
 
</script>

<svelte:head>
  <title>Newsletter - petRing</title>
  <link rel="canonical" href="https://webring.pet/newsletter/" />
  <link rel="alternate" type="application/rss+xml" title="The petRing newsletter" href="/newsletter/feed.xml" />
  <meta property="og:title" content="Newsletter - petRing" />
  <meta property="og:description" content="Updates and announcements on petRing." />
</svelte:head>

{#if auth.user}
  <div class="admin-bar">
    <a class="button" href="/admin/">+ new post</a>
  </div>
{/if}

{#if error}
  <p class="err">{error}</p>
{:else if loading}
  <p class="muted">Loading...</p>
{:else if newsletter.length === 0}
  <p class="muted">No entries yet.</p>
{:else}
  <div class="entries">
    {#each newsletter as entry (entry.id)}
      <article class="cell dither dither-corner">
        <div class="head">
          <h2><a href={`/newsletter/${entry.slug}/`}>{entry.title}</a></h2>
          {#if auth.user}
            <div class="admin-row">
              <a class="button" href={`/admin/?edit=${entry.id}`}>edit</a>
              <button type="button" class="danger" disabled={busy === entry.id} onclick={() => remove(entry.id)}>
                delete
              </button>
            </div>
          {/if}
        </div>
        <p class="date">
          {fmt(entry.posted_at)}{entry.authors.length ? ` · ${entry.authors.join(', ')}` : ''}
        </p>
        <RichMarkdown md={excerpt(entry.content_markdown, 2)} />
        <a class="more" href={`/newsletter/${entry.slug}/`}>read more ↗</a>
      </article>
    {/each}
  </div>
{/if}

<style>
 @reference '$appcss';

 .err {
   @apply text-(--color-error);
 }

 .muted {
   @apply text-(--color-subtext);
 }

 .admin-bar {
   @apply mb-4;
 }

 .admin-row {
   @apply mt-3 flex flex-wrap gap-2;
 }

 .danger {
   @apply text-(--color-error);
 }

 .entries {
   @apply flex flex-col;
 }

 .date {
   @apply mb-2.5 text-xs text-(--color-subtext-2);
 }

 article h2 {
   @apply mb-0.5 text-[1.15rem] font-bold;
 }

 article h2 a {
   @apply text-(--color-text) no-underline;
 }

 article h2 a:hover {
   @apply text-(--color-accent);
 }

 .more {
   @apply text-[.85rem] font-bold text-(--color-accent) no-underline;
 }

 .more:hover {
   @apply underline;
 }

 .head {
   @apply flex items-center justify-between gap-3;
 }

 .admin-row {
   @apply flex flex-wrap gap-2;
 }
</style>
