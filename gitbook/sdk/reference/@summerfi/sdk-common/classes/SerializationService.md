# Class: SerializationService

Defined in: [sdk/sdk-common/src/services/SerializationService.ts:9](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/services/SerializationService.ts#L9)

## Constructors

### Constructor

```ts
new SerializationService(): SerializationService;
```

#### Returns

`SerializationService`

## Methods

### getTransformer()

```ts
static getTransformer(): object;
```

Defined in: [sdk/sdk-common/src/services/SerializationService.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/services/SerializationService.ts#L31)

#### Returns

`object`

##### input

```ts
input: object;
```

###### input.deserialize()

```ts
deserialize: (serializedData) => unknown;
```

###### Parameters

###### serializedData

`string`

###### Returns

`unknown`

###### input.serialize()

```ts
serialize: (obj) => string;
```

###### Parameters

###### obj

`unknown`

###### Returns

`string`

##### output

```ts
output: object;
```

###### output.deserialize()

```ts
deserialize: (serializedData) => unknown;
```

###### Parameters

###### serializedData

`string`

###### Returns

`unknown`

###### output.serialize()

```ts
serialize: (obj) => string;
```

###### Parameters

###### obj

`unknown`

###### Returns

`string`

***

### parse()

```ts
static parse<T>(v): T;
```

Defined in: [sdk/sdk-common/src/services/SerializationService.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/services/SerializationService.ts#L27)

#### Type Parameters

##### T

`T`

#### Parameters

##### v

`string`

#### Returns

`T`

***

### registerClass()

```ts
static registerClass(v, options?): void;
```

Defined in: [sdk/sdk-common/src/services/SerializationService.ts:10](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/services/SerializationService.ts#L10)

#### Parameters

##### v

`object`

##### options?

`string` | `RegisterOptions`

#### Returns

`void`

***

### registerCustom()

```ts
static registerCustom<I, O>(transformer, name): void;
```

Defined in: [sdk/sdk-common/src/services/SerializationService.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/services/SerializationService.ts#L15)

#### Type Parameters

##### I

`I`

##### O

`O` *extends* `JSONValue`

#### Parameters

##### transformer

`Omit`\<`CustomTransfomer`\<`I`, `O`\>, `"name"`\>

##### name

`string`

#### Returns

`void`

***

### stringify()

```ts
static stringify(v): string;
```

Defined in: [sdk/sdk-common/src/services/SerializationService.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/services/SerializationService.ts#L23)

#### Parameters

##### v

`unknown`

#### Returns

`string`
