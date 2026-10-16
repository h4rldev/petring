export function excerpt(md: string, paragraphs = 2, max_chars = 700): string {
  const blocks = md.trim().split(/\n{2,}/);
  const out: string[] = [];
  let n = 0;
  for (const b of blocks) {
    if (out.length >= paragraphs || (out.length && n + b.length > max_chars))
      break;
    out.push(b);
    n += b.length;
  }
  return out
    .join("\n\n")
    .replace(
      /^(#{1,6})(\s)/gm,
      (_: string, h: string, s: string) =>
        "#".repeat(Math.min(6, h.length + 2)) + s,
    );
}
