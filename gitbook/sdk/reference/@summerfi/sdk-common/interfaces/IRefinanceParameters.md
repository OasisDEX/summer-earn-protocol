# Interface: IRefinanceParameters

Defined in: [sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts#L17)

Parameters for a refinance simulation

## Extends

- [`IRefinanceParametersData`](../type-aliases/IRefinanceParametersData.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts#L19)

Signature used to differentiate it from similar interfaces

***

### slippage

```ts
readonly slippage: IPercentage;
```

Defined in: [sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts#L25)

Maximum slippage allowed for the simulation

#### Overrides

```ts
IRefinanceParametersData.slippage
```

***

### sourcePosition

```ts
readonly sourcePosition: ILendingPosition;
```

Defined in: [sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts#L21)

Existing position to be refinanced

#### Overrides

```ts
IRefinanceParametersData.sourcePosition
```

***

### targetPool

```ts
readonly targetPool: ILendingPool;
```

Defined in: [sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts#L23)

Target pool where the source position will be moved

#### Overrides

```ts
IRefinanceParametersData.targetPool
```
