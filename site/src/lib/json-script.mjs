// Serialize a value for the body of a <script type="application/*json"> tag.
// JSON.stringify leaves `<` alone, and the HTML tokenizer ends a script element
// at the first `</script` whatever its type, so a string field carrying
// `</script><script>…` would break out and run. The \u escapes below are still
// valid JSON: JSON.parse (and every JSON-LD consumer) reads them back verbatim.
export function jsonForScript(value) {
  return JSON.stringify(value)
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/&/g, '\\u0026')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}
