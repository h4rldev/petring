<footer>
  <div class="foot dither">
    <nav>
      <a href="https://github.com/h4rldev/petring">GitHub</a>
      <a href="/newsletter/feed.xml" rel="external">RSS</a>
      <a href="/docs/">API</a>
    </nav>
  </div>
</footer>

<style>
 @reference '$appcss';

 footer {
   @apply px-4 pb-4;
 }

 .foot {
   @apply mx-auto flex max-w-[60rem] flex-wrap items-center justify-center gap-x-6 gap-y-1 border-2 border-(--color-surface-2) bg-(--color-primary) px-5 py-3 text-[.8rem] text-(--color-subtext);
   border-style: outset;
 }

 nav {
   @apply flex gap-4;
 }

 nav a {
   @apply tracking-[.03em] text-(--color-link) no-underline;
 }

 nav a:hover {
   @apply text-(--color-accent);
 }
</style>
