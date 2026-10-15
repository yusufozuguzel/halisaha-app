function createLazyPrivateLoginService({ create, getRateKey, getApiKey }) {
  let service;
  return () => {
    if (!service) service = create({ rateKey: getRateKey(), apiKey: getApiKey() });
    return service;
  };
}

module.exports = { createLazyPrivateLoginService };
