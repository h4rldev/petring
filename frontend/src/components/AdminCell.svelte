<script lang="ts">
 import type { Snippet } from 'svelte';

 let {
   name,
   title,
   open = $bindable(),
   children,
 }: { name: string; title: string; open?: boolean; children: Snippet } = $props();

 const storage_key = () => 'petring.admin.cell.' + name;

 function read_open() {
   if (typeof localStorage === 'undefined') return true;
   return (localStorage.getItem(storage_key()) ?? 'open') === 'open';
 }

 if (open === undefined) open = read_open();

 $effect(() => {
   try {
     localStorage.setItem(storage_key(), open ? 'open' : 'closed');
   } catch {}
 });
</script>

<details class="cell dither dither-corner" bind:open>
  <summary>{title}</summary>
  {@render children()}
</details>

<style>
 @reference '$appcss';

 summary {
   @apply cursor-pointer list-none text-base font-bold text-(--color-accent);
   user-select: none;
 }

 summary::-webkit-details-marker {
   display: none;
 }

 summary::before {
   content: '';
   border: 0.35rem solid transparent;
   border-left-color: currentColor;
   @apply mr-2 inline-block align-middle;
   transition: transform 0.15s;
 }

 details[open] > summary {
   @apply mb-3;
 }

 details[open] > summary::before {
   transform: rotate(90deg);
 }
</style>
