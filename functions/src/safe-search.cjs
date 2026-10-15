const likelihoods = new Set(['UNKNOWN', 'VERY_UNLIKELY', 'UNLIKELY', 'POSSIBLE', 'LIKELY', 'VERY_LIKELY']);

function safeSearchResult(annotation) {
  if (!annotation || typeof annotation !== 'object' || Array.isArray(annotation) ||
      !['adult', 'violence', 'racy'].every(key => likelihoods.has(annotation[key]) && annotation[key] !== 'UNKNOWN')) {
    throw new Error('Vision returned an incomplete SafeSearch annotation');
  }
  const unsafe = annotation.adult === 'LIKELY' || annotation.adult === 'VERY_LIKELY' ||
    annotation.violence === 'LIKELY' || annotation.violence === 'VERY_LIKELY' ||
    annotation.racy === 'VERY_LIKELY';
  return { safe: !unsafe };
}

module.exports = { safeSearchResult };
