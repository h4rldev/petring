<script lang="ts">
 import { onMount } from 'svelte';
 import { page } from '$app/state';
 import { api, type NewsletterEntry } from '$lib/petring_api';

 import RichMarkdown from '$components/RichMarkdown.svelte';
 import AdminCell from '$components/AdminCell.svelte';

 let entries = $state<NewsletterEntry[]>([]);
 let error = $state<string | null>(null);
 let busy = $state(false);

 let editing = $state<number | null>(null);
 let title = $state('');
 let slug = $state('');
 let slug_manually_edited = $state(false);
 let content = $state('');
 let status = $state<NewsletterEntry['status']>('published');
 let publish_at = $state('');

 const open_param = $derived(page.url.searchParams.get('edit') !== null);

 const fmt = (s: number) =>
   new Date(s * 1000).toLocaleDateString('en', { year: 'numeric', month: 'short', day: 'numeric' });

 const to_input = (s: number) => {
   const d = new Date(s * 1000);
   const p = (n: number) => String(n).padStart(2, '0');
   return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
 };

 onMount(load);

 const slugify = (s: string) =>
   s
     .toLowerCase()
     .replace(/[^a-z0-9]+/g, "-")
     .replace(/^-+|-+$/g, "");

 $effect(() => {
   if (!slug_manually_edited) slug = slugify(title);
 });

 async function load() {
   try {
     entries = await api.admin.list_newsletter();
     const id = page.url.searchParams.get('edit');
     if (id) {
       const e = entries.find((x) => String(x.id) === id);
       if (e) edit(e);
     }
   } catch (e) {
     error = (e as Error).message;
   }
 }

 function reset() {
   editing = null;
   slug_manually_edited = false;
   title = '';
   slug = '';
   content = '';
   status = 'published';
   publish_at = '';
 }

 function edit(e: NewsletterEntry) {
   editing = e.id;
   title = e.title;
   slug = e.slug;
   slug_manually_edited = true;
   content = e.content_markdown;
   status = e.status;
   publish_at = to_input(e.posted_at);
 }

 async function save(ev: SubmitEvent) {
   ev.preventDefault();
   if (!title.trim() || !slug.trim() || !content.trim()) {
     error = 'Title, slug and content are required.';
     return;
   }
   busy = true;
   error = null;
   try {
     const body = {
       title: title.trim(),
       slug: slug.trim(),
       content_markdown: content,
       status,
       posted_at: publish_at ? Math.floor(new Date(publish_at).getTime() / 1000) : undefined,
     };
     if (editing === null) await api.admin.create_newsletter(body);
     else await api.admin.update_newsletter(editing, body);
     await load();
     reset();
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
     await api.admin.delete_newsletter(id);
     if (editing === id) reset();
     await load();
   } catch (e) {
     error = (e as Error).message;
   } finally {
     busy = false;
   }
 }
</script>

<AdminCell name="newsletter" title="Newsletter" open={open_param || undefined}>
  <h3>{editing === null ? 'New post' : 'Edit post'}</h3>
  {#if error}<p class="err">{error}</p>{/if}

  <form onsubmit={save}>
    <label class="field">
      <span>title</span>
      <input bind:value={title} />
    </label>
    <label class="field">
      <span>slug</span>
      <input
        value={slug}
        oninput={(e) => {
          const s = slugify(e.currentTarget.value);
          slug_manually_edited = s !== "";
          slug = s;
        }}
        placeholder="auto-generated from title"
      />
      <span class="hint">Leave blank to auto-generate, or type a custom slug</span>
    </label>
    <label class="field">
      <span>content (markdown)</span>
      <textarea bind:value={content} rows="10"></textarea>
    </label>
    <div class="meta">
      <label class="field">
        <span>status</span>
        <select bind:value={status}>
          <option value="published">published</option>
          <option value="draft">draft</option>
        </select>
      </label>
      <label class="field">
        <span>publish at (blank = now)</span>
        <input type="datetime-local" bind:value={publish_at} />
      </label>
    </div>
    {#if content.trim()}
      <div class="preview"><RichMarkdown md={content} /></div>
    {/if}
    <div class="row">
      <button type="submit" disabled={busy}>{editing === null ? 'Publish' : 'Save'}</button>
      {#if editing !== null}
        <button type="button" disabled={busy} onclick={reset}>Cancel</button>
      {/if}
    </div>
  </form>

  <ul class="items">
    {#each entries as e (e.id)}
      <li>
        <div class="who">
          <strong>{e.title}</strong>
          <span class="slug">/{e.slug}</span>
          <span class="badge">{e.status}</span>
          <span class="time">{fmt(e.posted_at)}</span>
          <span class="authors">{e.authors.join(', ')}</span>
        </div>
        <div class="row">
          <button type="button" disabled={busy} onclick={() => edit(e)}>Edit</button>
          <button type="button" class="danger" disabled={busy} onclick={() => remove(e.id)}>Delete</button>
        </div>
      </li>
    {/each}
  </ul>
</AdminCell>

<style>
 @reference '$appcss';

 h3 {
   @apply mb-3 text-base font-bold text-(--color-accent);
 }

 form {
   @apply mb-5 flex flex-col gap-3;
 }

 .field {
   @apply flex flex-col gap-1;
 }

 .field span {
   @apply text-sm text-(--color-subtext);
 }

 .field .hint {
   @apply text-xs text-(--color-subtext-2);
 }

 .meta {
   @apply grid gap-4;
   grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr));
 }

 .preview {
   @apply border-2 border-(--color-surface-2) bg-(--color-bg) px-3 py-2;
   border-style: inset;
 }

 .row {
   @apply flex flex-wrap gap-2;
 }

 .items {
   @apply flex flex-col gap-3;
 }

 .items li {
   @apply flex items-center justify-between gap-4;
 }

 .who {
   @apply text-[.9rem];
 }

 .slug,
 .time,
 .badge {
   @apply ml-2 text-xs text-(--color-subtext-2);
 }

 .badge {
   @apply text-(--color-accent);
 }

 .authors {
   @apply ml-2 text-xs text-(--color-subtext-2);
 }

 .danger {
   @apply text-(--color-error);
 }

 .err {
   @apply text-(--color-error);
 }
</style>
