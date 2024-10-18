# Summer Earn Rates Subgraph

This subgraph indexes and tracks earn rates for various DeFi protocols across multiple networks.

## Configuration

The subgraph can be configured for different networks. Configuration files are located in the `config` directory.



### Network Configuration

To configure the subgraph for a specific network, edit the corresponding JSON file in the `config` directory. For example, for Arbitrum:

```json
{
  "network": "arbitrum-one",
  "entry_point_address": "0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3",
  "entry_point_start_block": 263570533,
  "interval-handler-block-interval": 2400
}

```

where:
- `network` is the network name
- `entry_point_address` is the address of the entry point
- `entry_point_start_block` is the first indexed block
- `interval-handler-block-interval` is the block interval of the interval handler 0 arbitrum one block is 250ms, hence 2400 blocks is 10 minutes

### Protocol Configuration

Protocols and their products are configured in `src/config/protocolConfig.ts`. To add or modify protocols:

1. Open `src/config/protocolConfig.ts`
2. Find the appropriate network initialization method (e.g., `initArbitrum()` for Arbitrum)
3. Add or modify the protocol and product instances as needed

Example:
```typescript
private initArbitrum(): Protocol[] {
    return [
        new Protocol('AaveV3', [
            new AaveV3Product(
            getOrCreateToken(addresses.USDC),
            Address.fromString('0x794a61358D6845594F94dc1DB02A252b5b4814aD'),
            BigInt.fromI32(7740843),
            'AaveV3',
            ),
            // Add more products here
        ]),
        // Add more protocols here
    ]
}
```

## Development

1. Install dependencies:
   ```
   pnpm install
   ```

2. Generate types:
   ```
   pnpm codegen
   ```

3. Build the subgraph:
   ```
   pnpm build
   ```

4. Deploy the subgraph:
   ```
   pnpm deploy
   ```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request