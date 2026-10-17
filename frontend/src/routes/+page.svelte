<script lang="ts">
 import RichMarkdown from '$components/RichMarkdown.svelte';
 import RegisterForm from '$components/RegisterForm.svelte';
 import ManageEntry from '$components/ManageEntry.svelte';
 import { api, type NewsletterEntry, type RandomAd, type Stats } from '$lib/petring_api';
 import { excerpt } from '$lib/markdown';
 import { theme } from '$lib/theme.svelte';

 let newsletter = $state<NewsletterEntry[]>([]);
 let ad = $state<RandomAd | null>(null);
 let stats = $state<Stats | null>(null);
 let error = $state<string | null>(null);
 let origin = $state('');
 let copied = $state<Record<string, boolean>>({});
 let preview = $state<HTMLIFrameElement>();
 let ring_name = $state('');
 let ring_preview_el = $state<HTMLIFrameElement>();

 const ring_slug = $derived(ring_name.trim() || 'YOURNAME');
 
 const embed = $derived(
   `<iframe src="${origin}/petads/" width="300" height="300" allowtransparency="true" frameborder="0"></iframe>`
 );

 const ring_embed = $derived(
   `<iframe src="${origin}/ring/?name=${ring_slug}" width="100%" height="32" allowtransparency="true" frameborder="0"></iframe>`
 );

 const ring_preview = $derived(`/ring/?name=${encodeURIComponent(ring_name.trim())}&theme=${theme.value}`);
 
 $effect(() => {
   if (preview) preview.src = '/petads/';
   if (ring_preview_el) ring_preview_el.src = ring_preview;
 });

 async function copy(key: string, text: string) {
   try {
     await navigator.clipboard.writeText(text);
     copied[key] = true;
     setTimeout(() => (copied[key] = false), 1500);
   } catch {}
 }

 const fmt = (s: number) =>
   new Date(s * 1000).toLocaleDateString('en', { year: 'numeric', month: 'short', day: 'numeric' });

 const num = (n?: number) => (n ?? 0).toLocaleString('en');
 
 $effect(() => {
   origin = location.origin;
   api.get_newsletter().then((n) => (newsletter = n)).catch((e) => (error = e.message));
   api.random_ad().then((a) => (ad = a)).catch(() => {});
   api.stats().then((s) => (stats = s)).catch(() => {});
 });
</script>

<svelte:head>
  <title>petRing: a pet-coded webring</title>
  <link rel="canonical" href="https://webring.pet/" />
  <meta property="og:url" content="https://webring.pet/" />
</svelte:head>

<section class="cell dither dither-corner">
  <h2>About</h2>
  <p class="lede">
    petRing is a pet-coded, queer-friendly webring and nav-link ads provider, that's free and fully open-source!
  </p>
  <div class="actions">
    <a class="button" rel="external" href="/api/users/random">Random site ↗</a>
    <a class="button" href="/newsletter/">Newsletter ↗</a>
    <a class="button" rel="external" href="/docs/">API ↗</a>
  </div>
  <div class="buttons">
    {#each ['dawn', 'dusk', 'midnight'] as t}
      <img src={`/petring-button-${t}.png`} alt={`petRing ${t} button`} width="88" height="31" />
    {/each}
  </div>
</section>

<section class="cell dither dither-corner">
  <div class="head">
    <h2>Newsletter</h2>
    <a class="more" href="/newsletter/">Index ↗</a>
  </div>

  {#if error}
    <p class="err">{error}</p>
  {:else if newsletter.length === 0}
    <p class="muted">No entries yet.</p>
  {:else}
    <div class="entries">
      {#each newsletter.slice(0, 3) as entry (entry.id)}
        <article>
          <h3><a href={`/newsletter/${entry.slug}/`}>{entry.title}</a></h3>
          <p class="date">{fmt(entry.posted_at)}</p>
          <RichMarkdown md={excerpt(entry.content_markdown, 2)} />
          <a class="more" href={`/newsletter/${entry.slug}/`}>Read more ↗</a>
        </article>
      {/each}
    </div>
  {/if}
</section>

<section class="cell dither dither-corner">
  <h2>Join the ring</h2>
  <div class="join">
    <div>
      <h3>New here?</h3>
      <p class="hint">Register your site to join the ring.</p>
      <RegisterForm />
    </div>
    <div>
      <h3>Already in the ring?</h3>
      <p class="hint">Paste the token you got when you signed up to edit your entry and ad.</p>
      <ManageEntry />
    </div>
  </div>
</section>

<section class="cell dither dither-corner" id="ring">
  <h2>Add the ring to your site</h2>
  <p class="lede">
    Verified in the ring? Embed the nav widget so visitors can hop member to member. Enter your
    username to preview it and get your snippet:
  </p>
  <div class="ring-demo">
    <label class="field">
      <span>username</span>
      <input bind:value={ring_name} maxlength="32" autocomplete="off" spellcheck="false" placeholder="your name" />
    </label>
    <iframe bind:this={ring_preview_el} height="34" title="petRing widget preview"></iframe>
  </div>
  <div class="embed">
    <div class="embed-head">
      <p class="hint">Copy this into your page:</p>
      <button class="button" onclick={() => copy('ring', ring_embed)}>{copied.ring ? 'Copied!' : 'Copy'}</button>
    </div>
    <code>{ring_embed}</code>
  </div>
  <p class="hint">
    Prefer to roll your own? Point any link at <code>{`/user/${ring_slug}/prev`}</code>,
    <code>{`/user/${ring_slug}/random`}</code> or <code>{`/user/${ring_slug}/next`}</code>, each
    redirects to that member's site. Full list in the <a href="/docs/">API docs</a>.
  </p>
</section>

<section class="cell dither dither-corner" id="petads">
  <h2>What is petAds?</h2>
  <p class="lede">
    petAds is the nav-link ads-system where petRing members can add their own image that advertises their own website, using a simple widget that anyone can embed onto theirs!
  </p>
  <div class="petads">
    <iframe bind:this={preview} height="300" title="PetAds widget example"></iframe>
    <div class="embed">
      <p class="hint">Copy this into your page:</p>
      <code>{embed}</code>
      <button class="button" onclick={() => copy('petads', embed)}>{copied.petads ? 'Copied!' : 'Copy'}</button>
    </div>
  </div>
</section>

<section class="cell dither dither-corner">
  <h2>Stats</h2>
  <div class="stats">
    <div class="stat"><span class="num">{num(stats?.members)}</span><span class="label">members</span></div>
    <div class="stat"><span class="num">{num(stats?.unique_visits)}</span><span class="label">unique visitors</span></div>
    <div class="stat"><span class="num">{num(stats?.visits)}</span><span class="label">visits</span></div>
    <div class="stat"><span class="num">{num(stats?.ads)}</span><span class="label">ads</span></div>
  </div>
</section>

<style>
 @reference '$appcss';

 h2 {
   @apply mb-3 font-bold text-(--color-accent);
 }

 .head {
   @apply flex items-baseline justify-between gap-4;
 }

 .lede {
   @apply mb-4 max-w-[46rem] text-(--color-subtext);
 }

 .actions {
   @apply mb-4 flex flex-wrap gap-2;
 }

 .buttons {
   @apply flex flex-wrap gap-2;
 }

 .entries {
   @apply mt-3 flex flex-col gap-6;
 }

 .entries article + article {
   @apply border-t-2 border-(--color-surface-2) pt-6;
 }
 
 article h3 {
   @apply mb-0.5 text-[1.15rem] font-bold;
 }

 article h3 a {
   @apply text-(--color-text) no-underline;
 }

 article h3 a:hover {
   @apply text-(--color-accent);
 }

 .date {
   @apply mb-2.5 text-xs text-(--color-subtext-2);
 }

 .muted {
   @apply text-(--color-subtext);
 }

 .err {
   @apply text-(--color-error);
 }

 .more {
   @apply text-[.85rem] font-bold text-(--color-accent) no-underline;
 }

 .more:hover {
   @apply underline;
 }

 .join {
   @apply grid gap-x-10 gap-y-8;
   grid-template-columns: repeat(auto-fit, minmax(min(20rem, 100%), 1fr));
 }

 .join h3 {
   @apply mb-1 text-[1.05rem] font-bold text-(--color-accent);
 }

 .join .hint {
   @apply mb-3 text-sm text-(--color-subtext);
   min-height: 2.5rem;
 }

 .stats {
   @apply grid gap-4;
   grid-template-columns: repeat(auto-fit, minmax(8rem, 1fr));
 }

 .stat {
   @apply flex flex-col items-center text-center;
 }

 .num {
   @apply text-2xl font-bold text-(--color-accent);
 }

 .label {
   @apply text-sm text-(--color-subtext);
 }

 #petads .petads {
   @apply flex flex-wrap items-start gap-6;
 }

 #petads iframe {
   @apply border-2 border-(--color-surface-2);
   border-style: outset;
   width: 300px;
   max-width: 100%;
   height: 300px;
 }

 #petads .embed,
 #ring .embed {
   @apply flex flex-col items-start gap-2;
 }

 #petads .embed {
   @apply min-w-[16rem] flex-1;
 }

 #petads .embed code,
 #ring .embed code {
   @apply block w-full border-2 border-(--color-surface-2) bg-(--color-bg) px-3 py-2 text-[.8rem];
   white-space: pre-wrap;
   word-break: break-all;
 }

 #petads .hint,
 #ring .hint {
   @apply text-sm text-(--color-subtext);
 }

 #petads button,
 #ring button {
   @apply cursor-pointer;
 }

 #ring .ring-demo {
   @apply mb-4;
   display: grid;
   grid-template-columns: minmax(0, 20rem) minmax(0, 20rem);
   justify-content: center;
   align-items: center;
   column-gap: 1.5rem;
   row-gap: 0.25rem;
 }

 #ring .ring-demo .field {
   display: contents;
 }

 #ring .ring-demo .field span {
   @apply text-sm text-(--color-subtext);
   grid-column: 1;
   grid-row: 1;
 }

 #ring .ring-demo .field input {
   grid-column: 1;
   grid-row: 2;
 }

 #ring .ring-demo iframe {
   @apply border-0;
   grid-column: 2;
   grid-row: 2;
   width: 100%;
   height: 34px;
 }

 #ring .embed {
   @apply mb-4;
 }
 
 #ring .embed-head {
   @apply mb-1 flex w-full flex-wrap items-center justify-between gap-3;
 }

 #ring .embed-head .hint {
   @apply mb-0;
 }
 
 #ring .hint code {
   @apply bg-(--color-bg) px-1;
 }
</style>
