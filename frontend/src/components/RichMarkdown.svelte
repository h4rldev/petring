<script lang="ts">
 import Markdown from 'svelte-exmarkdown';
 import { gfmPlugin } from 'svelte-exmarkdown/gfm';

 let { md }: { md: string } = $props();
 const plugins = [gfmPlugin()];
</script>

<div class="md prose max-w-none dark:prose-invert">
  <Markdown {md} {plugins} />
</div>

<style>
  @reference '$appcss';

  .md :global(h1),
  .md :global(h2),
  .md :global(h3),
  .md :global(h4) {
    @apply font-bold tracking-[.02em] text-(--color-accent);
  }

  .md :global(a) {
    @apply text-(--color-link);
  }

  .md :global(code) {
    @apply before:content-none after:content-none;
  }
</style>
