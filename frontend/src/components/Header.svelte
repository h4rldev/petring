<script lang="ts">
 import { page } from '$app/state';
 import { auth } from '$lib/auth.svelte';
 import logotype from '$lib/assets/petring-logotype.png';
 import ThemeToggle from '$components/ThemeToggle.svelte';

 const links = [
   { href: '/', label: 'Home' },
   { href: '/newsletter/', label: 'Newsletter' },
   { href: '/docs/', label: 'API' }
 ];
 const active = $derived(page.url.pathname);
</script>

<header>
  <div class="bar dither">
    <a class="logo" href="/">
      <span>petRing</span>
      <img src={logotype} alt="" />
    </a>
    <nav>
      {#each links as l}
        <a href={l.href} aria-current={active === l.href ? 'page' : undefined}
           class:active={active === l.href}>{l.label}</a>
      {/each}
    </nav>
    <div class="session">
      {#if auth.user}
        <a href="/admin/" class:active={active === '/admin/'}>Admin</a>
      {:else}
        <a href="/login/" class:active={active === '/login/'}>Login</a>
      {/if}
      <ThemeToggle />
    </div>
  </div>
</header>

<style>
 @reference '$appcss';

 header {
   @apply px-4 pt-4;
 }

 .bar {
   @apply mx-auto flex max-w-[60rem] flex-wrap items-center gap-x-5 gap-y-1 border-2 border-(--color-surface-2) bg-(--color-primary) px-5 py-3 max-sm:items-start;
   border-style: outset;
 }

 .logo {
   @apply inline-flex items-center gap-2.5 no-underline;
 }

 .logo span {
   @apply font-display text-[1.7rem] leading-none tracking-[.03em] text-(--color-accent);
 }

 .logo img {
   @apply h-[2.1rem] w-auto;
   image-rendering: pixelated;
 }

 nav {
   @apply flex flex-wrap gap-x-4 gap-y-0.5 max-sm:ml-auto max-sm:flex-col max-sm:items-end;
 }

 nav a,
 .session a {
   @apply relative py-0.5 font-sans text-[.85rem] tracking-[.05em] text-(--color-subtext) no-underline;
 }

 nav a::after,
 .session a::after {
   content: '';
   @apply pointer-events-none absolute inset-x-0 bottom-0 h-0.5 bg-(--color-accent);
   opacity: 0;
   transition: opacity 0.2s ease-in-out;
 }

 nav a:hover,
 .session a:hover,
 nav a.active,
 .session a.active {
   @apply text-(--color-accent);
 }

 nav a:hover::after,
 .session a:hover::after,
 nav a.active::after,
 .session a.active::after {
   opacity: 1;
 }
 
 .session {
   @apply ml-auto flex items-center gap-x-4 max-sm:ml-0 max-sm:w-full max-sm:justify-end;
 }
</style>
