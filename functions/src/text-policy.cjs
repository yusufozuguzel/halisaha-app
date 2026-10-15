// Deliberately modest exact-word screening for public text. This avoids the
// client's easy-to-bypass-only check without rejecting short substrings in
// ordinary Turkish names. It is not a general language moderation system.
const DENIED_PUBLIC_WORDS = new Set([
  'orospu', 'siktir', 'sikerim', 'yarrak', 'yavşak', 'yavsak', 'gavat',
  'pezevenk', 'kahpe', 'fuck', 'shit', 'bitch', 'asshole', 'pussy', 'cunt',
  'whore', 'slut', 'faggot', 'nigger', 'nigga',
]);

function publicTextAllowed(value, maximum) {
  if (typeof value !== 'string' || value.length > maximum || /[\u0000-\u001f\u007f]/.test(value)) return false;
  const tokens = value.normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase()
    .split(/[^\p{L}\p{N}_]+/u).filter(Boolean);
  return !tokens.some(token => DENIED_PUBLIC_WORDS.has(token));
}

module.exports = { DENIED_PUBLIC_WORDS, publicTextAllowed };
