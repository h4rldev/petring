<script lang="ts">
import { theme, THEMES, init_theme, set_theme } from '$lib/theme.svelte';

 $effect(() => {
   init_theme();
 });
</script>

<div class="themes" role="group" aria-label="theme">
  {#each THEMES as t}
    <button type="button" class:active={theme.value === t} onclick={() => set_theme(t)}>{t}</button>
  {/each}
</div>

<style>
 @reference '$appcss';

 .themes {
   @applt flex gap-1;
 }

 .themes button {
   @apply px-2 text-[.75rem] capitalize;
 }

 .themes button.active {
   @apply bg-(--color-accent) text-(--color-on-accent);
   border-style: inset;
 }
</style>
