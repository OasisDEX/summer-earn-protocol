# Type Alias: UnsignedOrder

```ts
type UnsignedOrder = Omit<OrderParameters, "receiver"> & object;
```

Defined in: node\_modules/.pnpm/@cowprotocol+sdk-order-signing@0.3.0/node\_modules/@cowprotocol/sdk-order-signing/dist/index.d.ts:9

Unsigned order intent to be placed.

## Type Declaration

### receiver

```ts
receiver: string;
```
