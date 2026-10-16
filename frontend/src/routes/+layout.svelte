<script lang="ts">
 import { onMount } from 'svelte';
 import { auth } from '$lib/auth.svelte';
 
 import '$appcss';
 import Header from '$components/Header.svelte';
 import Footer from '$components/Footer.svelte';

 let { children } = $props();

 onMount(() => {
   auth.check();
 });
</script>

<Header />
<main>
  {@render children()}
</main>
<Footer />

<style>
 @reference '$appcss';
 
 main {
   @apply mx-auto w-full max-w-[60rem] px-4 py-7;
 }
</style>
