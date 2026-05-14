const WALLETS = {
  BTC: ['1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa', '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy', 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'],
  ETH: ['0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18', '0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B', '0x4e83362442b8d1bec281594ceA3052c8eb01311c'],
  USDT: ['0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18', '0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B', '0x4e83362442b8d1bec281594ceA3052c8eb01311c'],
  SOL: ['7EcDhSYGxXyscszYEp35KHN8vvw3svAuA2crcNfpJhA9', 'DKp7aJxuYpAVNQmBQjgCAnw5cK2sPjgJiQFJ9RVGHoSo', 'GWyRfEUgNPdK3fQJEk1WZ7fJKGcFJ7jLJ6GgHLVpGVy1'],
};

export const NETWORKS = Object.keys(WALLETS);

export function getRandomWallet(network) {
  const wallets = WALLETS[network] || WALLETS.USDT;
  return wallets[Math.floor(Math.random() * wallets.length)];
}
