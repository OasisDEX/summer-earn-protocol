# Interface: SwapStep

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:75](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L75)

## Extends

- [`Step`](Step.md)\<[`Swap`](../../../enumerations/SimulationSteps.md#swap), \{
  `estimatedReceivedAmount`: [`ITokenAmount`](../../../interfaces/ITokenAmount.md);
  `inputAmount`: [`ITokenAmount`](../../../interfaces/ITokenAmount.md);
  `inputAmountAfterFee`: [`ITokenAmount`](../../../interfaces/ITokenAmount.md);
  `minimumReceivedAmount`: [`ITokenAmount`](../../../interfaces/ITokenAmount.md);
  `offerPrice`: [`IPrice`](../../../interfaces/IPrice.md);
  `provider`: [`SwapProviderType`](../../../enumerations/SwapProviderType.md);
  `routes`: [`SwapRoute`](../../../type-aliases/SwapRoute.md)[];
  `slippage`: [`IPercentage`](../../../interfaces/IPercentage.md);
  `spotPrice`: [`IPrice`](../../../interfaces/IPrice.md);
  `summerFee`: [`IPercentage`](../../../interfaces/IPercentage.md);
\}, \{
  `received`: [`ITokenAmount`](../../../interfaces/ITokenAmount.md);
\}\>

## Properties

### inputs

```ts
inputs: object;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L20)

#### estimatedReceivedAmount

```ts
estimatedReceivedAmount: ITokenAmount;
```

Amount estimated by the swap service to be received, equal to `inputAmountAfterFee / offerPrice`

#### inputAmount

```ts
inputAmount: ITokenAmount;
```

Full amount sent to the swap contract, before deducting the Summer fee

#### inputAmountAfterFee

```ts
inputAmountAfterFee: ITokenAmount;
```

Amount to be swapped after deducting the Summer fee

#### minimumReceivedAmount

```ts
minimumReceivedAmount: ITokenAmount;
```

Minimum amount to be received from the swap service, equal to `inputAmountAfterFee / offerPrice * (1 - slippage)`

#### offerPrice

```ts
offerPrice: IPrice;
```

Offer price of the token being traded, derived from the swap quote

#### provider

```ts
provider: OneInch;
```

#### routes

```ts
routes: SwapRoute[];
```

#### slippage

```ts
slippage: IPercentage;
```

Maximum slippage accepted for the swap

#### spotPrice

```ts
spotPrice: IPrice;
```

Spot price of the token being traded

#### summerFee

```ts
summerFee: IPercentage;
```

Fee charged by Summer

#### Inherited from

[`Step`](Step.md).[`inputs`](Step.md#inputs)

***

### name

```ts
name: string;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L19)

#### Inherited from

[`Step`](Step.md).[`name`](Step.md#name)

***

### outputs

```ts
outputs: object;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L21)

#### received

```ts
received: ITokenAmount;
```

Effective amount received after the actual swap

#### Inherited from

[`Step`](Step.md).[`outputs`](Step.md#outputs)

***

### skip?

```ts
optional skip: boolean;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L22)

#### Inherited from

[`Step`](Step.md).[`skip`](Step.md#skip)

***

### type

```ts
type: Swap;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/Steps.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/Steps.ts#L18)

#### Inherited from

[`Step`](Step.md).[`type`](Step.md#type)
