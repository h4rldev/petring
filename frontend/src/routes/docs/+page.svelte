<script lang="ts">
 import { onMount } from "svelte";
 import { auth } from "$lib/auth.svelte";
 import { groups, rank, type Endpoint, type Group } from "$lib/docs";

 const account = $derived(auth.user);
 let token = $state("");
 let open = $state<Record<string, boolean>>({});
 let params = $state<Record<string, Record<string, string>>>({});
 let queries = $state<Record<string, Record<string, string>>>({});
 let bodies = $state<Record<string, string>>({});
 let results = $state<Record<string, { status: number; ok: boolean; body: string } | null>>({});
 let sending = $state<Record<string, boolean>>({});

 const dry = (e: Endpoint) => isWrite(e.method) || e.dry === true;
 const key = (e: Endpoint) => `${e.method} ${e.path}`;
 const isWrite = (m: string) => m === "POST" || m === "PATCH" || m === "PUT" || m === "DELETE";
 const visible = (g: Group) => g.scope !== "admin" || rank(account?.role) >= 1;
 const param_names = (e: Endpoint) => [...e.path.matchAll(/:([A-Za-z_]+)/g)].map((m) => m[1]);
 const missing = (e: Endpoint) => param_names(e).some((n) => !(params[key(e)]?.[n] ?? "").trim());
 
 const path_for = (e: Endpoint) => {
   let p = e.path;
   const vals = params[key(e)] ?? {};
   for (const n of param_names(e)) p = p.replace(`:${n}`, vals[n] ?? `:${n}`);
   return p;
 };

 const query_defaults = (e: Endpoint) => {
   const init: Record<string, string> = {};
   for (const q of e.query ?? []) init[q.name] = q.example ?? "";
   return init;
 };
 
 const query_for = (e: Endpoint) => {
   const vals = queries[key(e)] ?? {};
   const p = new URLSearchParams();
   for (const q of e.query ?? []) {
     const v = (vals[q.name] ?? "").trim();
     if (v) p.set(q.name, v);
   }
   const s = p.toString();
   return s ? `?${s}` : "";
 };
 
 const url_for = (e: Endpoint) => path_for(e) + query_for(e);
 
 function toggle(e: Endpoint) {
   const k = key(e);
   open[k] = !open[k];
   if (open[k]) {
     if (bodies[k] === undefined) bodies[k] = e.body ?? "";
     if (params[k] === undefined) params[k] = {};
     if (queries[k] === undefined) queries[k] = query_defaults(e);
   }
 }

 function pretty(text: string, res?: Response): string {
   if (!text.trim()) return res?.redirected ? `→ ${res.url}` : "(empty response)";
   try {
     return JSON.stringify(JSON.parse(text), null, 2);
   } catch {
     return text;
   }
 }

 async function send(e: Endpoint) {
   const k = key(e);
   if (missing(e)) {
     results[k] = { status: 0, ok: false, body: `Fill in ${param_names(e).map((n) => ":" + n).join(", ")} first.` };
     return;
   }
   sending[k] = true;
   results[k] = null;
   const headers: Record<string, string> = {};
   let body: string | undefined;
   if (dry(e)) {
     body = (bodies[k] ?? e.body ?? "").trim() || undefined;
     if (body) headers["content-type"] = "application/json";
     headers["x-dry-run"] = "true";
   }
   if (e.path.startsWith("/api/manage") && token) headers["authorization"] = `Bearer ${token}`;
   try {
     const res = await fetch(url_for(e), { method: e.method, headers, body });
     results[k] = { status: res.status, ok: res.ok, body: pretty(await res.text(), res) };
   } catch (err) {
     results[k] = { status: 0, ok: false, body: String(err) };
   }
   sending[k] = false;
 }
</script>

<svelte:head><title>API reference — petRing</title></svelte:head>

<section class="cell dither dither-corner">
  <h1>API reference</h1>
  <p class="lede">
    Everything lives under <code>/api</code> and speaks JSON; errors are
    <code>&#123;status, message&#125;</code> and timestamps are Unix seconds. The
    "try it" calls hit the live server. Write requests (<b>POST/PATCH/PUT/DELETE</b>)
    are sent with <code>X-Dry-Run: true</code>, so the backend echoes what it
    received and changes nothing.
  </p>
  <p class="lede">
    {#if account}
      Signed in as <b>{account.username}</b> ({account.role}).
    {:else}
      Public view. Admin routes appear once you're signed in as an admin.
    {/if}
  </p>
</section>

{#each groups as g (g.id)}
  {#if visible(g)}
    <section class="cell dither dither-corner">
      <h2>{g.title} <span class="scope {g.scope}">{g.scope}</span></h2>
      <p class="lede">{g.blurb}</p>
      {#if g.auth}<p class="auth">{g.auth}</p>{/if}
      {#if g.scope === "manage"}
        <label class="token">Manage token, on this tab only, never stored
          <input type="password" bind:value={token} placeholder="paste your one-time manage token" autocomplete="off" />
        </label>
      {/if}
      <ul class="eps">
        {#each g.endpoints as e (key(e))}
          {@const k = key(e)}
          <li>
            <button class="row" onclick={() => toggle(e)} aria-expanded={open[k]}>
              <span class="method {e.method.toLowerCase()}">{e.method}</span>
              <code class="path">{e.path}</code>
              <span class="desc">{e.desc}</span>
            </button>
            {#if open[k]}
              <div class="try">
                {#if param_names(e).length || e.query?.length}
                  <div class="params">
                    {#each param_names(e) as n}
                      <label>{n}
                        <input bind:value={params[k][n]} placeholder={`:${n}`} autocomplete="off" />
                      </label>
                    {/each}
                    {#each e.query ?? [] as q}
                      <label>{q.name}
                        <input bind:value={queries[k][q.name]} placeholder={q.example ?? ""} autocomplete="off" />
                      </label>
                    {/each}
                  </div>
                {/if}
                {#if e.body}
                  <label>Request body
                    <textarea bind:value={bodies[k]} spellcheck="false"></textarea>
                  </label>
                {/if}
                {#if e.returns}<p class="meta">Returns <code>{e.returns}</code></p>{/if}
                {#if e.try !== false}
                  <div class="actions">
                    <button class="send" disabled={sending[k] || missing(e)} onclick={() => send(e)}>
                      {sending[k] ? "Sending…" : isWrite(e.method) ? "Dry run" : "Send"}
                    </button>
                    {#if isWrite(e.method)}<span class="note">X-Dry-Run is true, nothing is written</span>{/if}
                  </div>
                  {#if results[k]}
                    <pre class="out" class:ok={results[k].ok} class:err={!results[k].ok}>{results[k].status} {results[k].body}</pre>
                  {/if}
                {/if}
              </div>
            {/if}
          </li>
        {/each}
      </ul>
    </section>
  {/if}
{/each}

<style>
 @reference '$appcss';

 h1 {
   @apply mb-3 font-sans text-3xl text-(--color-accent);
 }
 
 h2 {
   @apply mb-2 flex items-center gap-3 text-xl;
 }
 
 .lede {
   @apply mb-3 text-(--color-subtext);
 }
 
 .lede code, .meta code {
   @apply bg-(--color-bg) px-1;
 }
 
 .scope {
   @apply px-1.5 py-0.5 text-[.7rem] uppercase tracking-widest;
 }
 
 .scope.public {
   @apply bg-(--color-confirm) text-(--color-on-accent);
 }
 
 .scope.manage {
   @apply bg-(--color-info) text-(--color-on-accent);
 }
 
 .scope.admin {
   @apply bg-(--color-warning) text-(--color-on-accent);
 }
 
 .auth {
   @apply mb-3 text-sm text-(--color-subtext-2);
 }
 
 .eps {
   @apply list-none p-0;
 }
 
 .eps li {
   @apply border-t border-(--color-surface-2);
 }
 
 .row {
   @apply flex w-full cursor-pointer items-center justify-start gap-3 border-0 bg-transparent py-2 text-left;
 }
 
 .method {
   @apply w-16 shrink-0 px-1 py-0.5 text-center text-[.7rem] font-bold tracking-[.08em];
 }
 
 .method.get {
   @apply bg-(--color-confirm) text-(--color-on-accent);
 }
 
 .method.post {
   @apply bg-(--color-info) text-(--color-on-accent);
 }
 
 .method.put {
   @apply bg-(--color-accent) text-(--color-on-accent);
 }
 
 .method.patch {
   @apply bg-(--color-warning) text-(--color-on-accent);
 }
 
 .method.delete {
   @apply bg-(--color-error) text-(--color-on-accent);
 }
 
 .method.ws {
   @apply bg-(--color-subtext-2) text-(--color-on-accent);
 }
 
 .path {
   @apply font-mono text-sm;
 }
 
 .desc {
   @apply text-sm text-(--color-subtext);
 }
 
 .try {
   @apply pb-3 pl-[5.5rem];
 }
 
 label {
   @apply flex flex-col gap-1 text-xs text-(--color-subtext-2);
 }
 
 textarea {
   @apply h-24 w-full border-2 bg-(--color-bg) p-2 font-mono text-sm; border-style: inset;
 }
 
 .meta {
   @apply mt-2 text-xs text-(--color-subtext-2);
 }
 
 .actions {
   @apply mt-2 flex items-center gap-3;
 }
 
 .send {
   @apply cursor-pointer border-2 border-(--color-surface-2) bg-(--color-secondary) px-3 py-1; border-style: outset;
 }
 
 .send:hover {
   @apply bg-(--color-accent) text-(--color-on-accent);
 }
 
 .note {
   @apply text-xs text-(--color-subtext-2);
 }
 
 .out {
   @apply mt-2 overflow-x-auto border-2 border-(--color-surface-2) bg-(--color-bg) p-2 text-xs;
 }
 
 .out.ok {
   @apply text-(--color-confirm);
 }
 
 .out.err {
   @apply text-(--color-error);
 }

 .token {
   @apply mb-3 flex flex-col gap-1 text-xs text-(--color-subtext-2);
 }
 
 .params {
   @apply mb-2 flex flex-wrap gap-3;
 }
 
 .params label {
   @apply flex flex-col gap-1 text-xs text-(--color-subtext-2);
 }
 
 .token input,
 .params input {
   @apply border-2 bg-(--color-bg) px-2 py-1 font-mono text-sm; border-style: inset;
 }
</style>
