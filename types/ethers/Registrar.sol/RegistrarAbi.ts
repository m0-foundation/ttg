/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type {
  FunctionFragment,
  Result,
  EventFragment,
} from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
} from "../common";

export interface RegistrarAbiInterface extends utils.Interface {
  functions: {
    "addToList(bytes32,address)": FunctionFragment;
    "get(bytes32)": FunctionFragment;
    "get(bytes32[])": FunctionFragment;
    "governor()": FunctionFragment;
    "governorDeployer()": FunctionFragment;
    "listContains(bytes32,address[])": FunctionFragment;
    "listContains(bytes32,address)": FunctionFragment;
    "powerTokenDeployer()": FunctionFragment;
    "removeFromList(bytes32,address)": FunctionFragment;
    "reset()": FunctionFragment;
    "updateConfig(bytes32,bytes32)": FunctionFragment;
    "zeroToken()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "addToList"
      | "addToList(bytes32,address)"
      | "get(bytes32)"
      | "get(bytes32[])"
      | "governor"
      | "governor()"
      | "governorDeployer"
      | "governorDeployer()"
      | "listContains(bytes32,address[])"
      | "listContains(bytes32,address)"
      | "powerTokenDeployer"
      | "powerTokenDeployer()"
      | "removeFromList"
      | "removeFromList(bytes32,address)"
      | "reset"
      | "reset()"
      | "updateConfig"
      | "updateConfig(bytes32,bytes32)"
      | "zeroToken"
      | "zeroToken()"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "addToList",
    values: [BytesLike, string]
  ): string;
  encodeFunctionData(
    functionFragment: "addToList(bytes32,address)",
    values: [BytesLike, string]
  ): string;
  encodeFunctionData(
    functionFragment: "get(bytes32)",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "get(bytes32[])",
    values: [BytesLike[]]
  ): string;
  encodeFunctionData(functionFragment: "governor", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "governor()",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "governorDeployer",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "governorDeployer()",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "listContains(bytes32,address[])",
    values: [BytesLike, string[]]
  ): string;
  encodeFunctionData(
    functionFragment: "listContains(bytes32,address)",
    values: [BytesLike, string]
  ): string;
  encodeFunctionData(
    functionFragment: "powerTokenDeployer",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "powerTokenDeployer()",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "removeFromList",
    values: [BytesLike, string]
  ): string;
  encodeFunctionData(
    functionFragment: "removeFromList(bytes32,address)",
    values: [BytesLike, string]
  ): string;
  encodeFunctionData(functionFragment: "reset", values?: undefined): string;
  encodeFunctionData(functionFragment: "reset()", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "updateConfig",
    values: [BytesLike, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "updateConfig(bytes32,bytes32)",
    values: [BytesLike, BytesLike]
  ): string;
  encodeFunctionData(functionFragment: "zeroToken", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "zeroToken()",
    values?: undefined
  ): string;

  decodeFunctionResult(functionFragment: "addToList", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "addToList(bytes32,address)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "get(bytes32)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "get(bytes32[])",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "governor", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "governor()", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "governorDeployer",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "governorDeployer()",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "listContains(bytes32,address[])",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "listContains(bytes32,address)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "powerTokenDeployer",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "powerTokenDeployer()",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "removeFromList",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "removeFromList(bytes32,address)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "reset", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "reset()", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "updateConfig",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "updateConfig(bytes32,bytes32)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "zeroToken", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "zeroToken()",
    data: BytesLike
  ): Result;

  events: {
    "AddressAddedToList(bytes32,address)": EventFragment;
    "AddressRemovedFromList(bytes32,address)": EventFragment;
    "ConfigUpdated(bytes32,bytes32)": EventFragment;
    "ResetExecuted()": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "AddressAddedToList"): EventFragment;
  getEvent(
    nameOrSignatureOrTopic: "AddressAddedToList(bytes32,address)"
  ): EventFragment;
  getEvent(nameOrSignatureOrTopic: "AddressRemovedFromList"): EventFragment;
  getEvent(
    nameOrSignatureOrTopic: "AddressRemovedFromList(bytes32,address)"
  ): EventFragment;
  getEvent(nameOrSignatureOrTopic: "ConfigUpdated"): EventFragment;
  getEvent(
    nameOrSignatureOrTopic: "ConfigUpdated(bytes32,bytes32)"
  ): EventFragment;
  getEvent(nameOrSignatureOrTopic: "ResetExecuted"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "ResetExecuted()"): EventFragment;
}

export interface AddressAddedToListEventObject {
  list: string;
  account: string;
}
export type AddressAddedToListEvent = TypedEvent<
  [string, string],
  AddressAddedToListEventObject
>;

export type AddressAddedToListEventFilter =
  TypedEventFilter<AddressAddedToListEvent>;

export interface AddressRemovedFromListEventObject {
  list: string;
  account: string;
}
export type AddressRemovedFromListEvent = TypedEvent<
  [string, string],
  AddressRemovedFromListEventObject
>;

export type AddressRemovedFromListEventFilter =
  TypedEventFilter<AddressRemovedFromListEvent>;

export interface ConfigUpdatedEventObject {
  key: string;
  value: string;
}
export type ConfigUpdatedEvent = TypedEvent<
  [string, string],
  ConfigUpdatedEventObject
>;

export type ConfigUpdatedEventFilter = TypedEventFilter<ConfigUpdatedEvent>;

export interface ResetExecutedEventObject {}
export type ResetExecutedEvent = TypedEvent<[], ResetExecutedEventObject>;

export type ResetExecutedEventFilter = TypedEventFilter<ResetExecutedEvent>;

export interface RegistrarAbi extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: RegistrarAbiInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    addToList(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    "addToList(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    "get(bytes32)"(
      key_: BytesLike,
      overrides?: CallOverrides
    ): Promise<[string] & { value_: string }>;

    "get(bytes32[])"(
      keys_: BytesLike[],
      overrides?: CallOverrides
    ): Promise<[string[]] & { values_: string[] }>;

    governor(overrides?: CallOverrides): Promise<[string]>;

    "governor()"(overrides?: CallOverrides): Promise<[string]>;

    governorDeployer(overrides?: CallOverrides): Promise<[string]>;

    "governorDeployer()"(overrides?: CallOverrides): Promise<[string]>;

    "listContains(bytes32,address[])"(
      list_: BytesLike,
      accounts_: string[],
      overrides?: CallOverrides
    ): Promise<[boolean] & { contains_: boolean }>;

    "listContains(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: CallOverrides
    ): Promise<[boolean] & { contains_: boolean }>;

    powerTokenDeployer(overrides?: CallOverrides): Promise<[string]>;

    "powerTokenDeployer()"(overrides?: CallOverrides): Promise<[string]>;

    removeFromList(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    "removeFromList(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    reset(
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    "reset()"(
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    updateConfig(
      key_: BytesLike,
      value_: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    "updateConfig(bytes32,bytes32)"(
      key_: BytesLike,
      value_: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    zeroToken(overrides?: CallOverrides): Promise<[string]>;

    "zeroToken()"(overrides?: CallOverrides): Promise<[string]>;
  };

  addToList(
    list_: BytesLike,
    account_: string,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  "addToList(bytes32,address)"(
    list_: BytesLike,
    account_: string,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  "get(bytes32)"(key_: BytesLike, overrides?: CallOverrides): Promise<string>;

  "get(bytes32[])"(
    keys_: BytesLike[],
    overrides?: CallOverrides
  ): Promise<string[]>;

  governor(overrides?: CallOverrides): Promise<string>;

  "governor()"(overrides?: CallOverrides): Promise<string>;

  governorDeployer(overrides?: CallOverrides): Promise<string>;

  "governorDeployer()"(overrides?: CallOverrides): Promise<string>;

  "listContains(bytes32,address[])"(
    list_: BytesLike,
    accounts_: string[],
    overrides?: CallOverrides
  ): Promise<boolean>;

  "listContains(bytes32,address)"(
    list_: BytesLike,
    account_: string,
    overrides?: CallOverrides
  ): Promise<boolean>;

  powerTokenDeployer(overrides?: CallOverrides): Promise<string>;

  "powerTokenDeployer()"(overrides?: CallOverrides): Promise<string>;

  removeFromList(
    list_: BytesLike,
    account_: string,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  "removeFromList(bytes32,address)"(
    list_: BytesLike,
    account_: string,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  reset(
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  "reset()"(
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  updateConfig(
    key_: BytesLike,
    value_: BytesLike,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  "updateConfig(bytes32,bytes32)"(
    key_: BytesLike,
    value_: BytesLike,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  zeroToken(overrides?: CallOverrides): Promise<string>;

  "zeroToken()"(overrides?: CallOverrides): Promise<string>;

  callStatic: {
    addToList(
      list_: BytesLike,
      account_: string,
      overrides?: CallOverrides
    ): Promise<void>;

    "addToList(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: CallOverrides
    ): Promise<void>;

    "get(bytes32)"(key_: BytesLike, overrides?: CallOverrides): Promise<string>;

    "get(bytes32[])"(
      keys_: BytesLike[],
      overrides?: CallOverrides
    ): Promise<string[]>;

    governor(overrides?: CallOverrides): Promise<string>;

    "governor()"(overrides?: CallOverrides): Promise<string>;

    governorDeployer(overrides?: CallOverrides): Promise<string>;

    "governorDeployer()"(overrides?: CallOverrides): Promise<string>;

    "listContains(bytes32,address[])"(
      list_: BytesLike,
      accounts_: string[],
      overrides?: CallOverrides
    ): Promise<boolean>;

    "listContains(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: CallOverrides
    ): Promise<boolean>;

    powerTokenDeployer(overrides?: CallOverrides): Promise<string>;

    "powerTokenDeployer()"(overrides?: CallOverrides): Promise<string>;

    removeFromList(
      list_: BytesLike,
      account_: string,
      overrides?: CallOverrides
    ): Promise<void>;

    "removeFromList(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: CallOverrides
    ): Promise<void>;

    reset(overrides?: CallOverrides): Promise<void>;

    "reset()"(overrides?: CallOverrides): Promise<void>;

    updateConfig(
      key_: BytesLike,
      value_: BytesLike,
      overrides?: CallOverrides
    ): Promise<void>;

    "updateConfig(bytes32,bytes32)"(
      key_: BytesLike,
      value_: BytesLike,
      overrides?: CallOverrides
    ): Promise<void>;

    zeroToken(overrides?: CallOverrides): Promise<string>;

    "zeroToken()"(overrides?: CallOverrides): Promise<string>;
  };

  filters: {
    "AddressAddedToList(bytes32,address)"(
      list?: BytesLike | null,
      account?: string | null
    ): AddressAddedToListEventFilter;
    AddressAddedToList(
      list?: BytesLike | null,
      account?: string | null
    ): AddressAddedToListEventFilter;

    "AddressRemovedFromList(bytes32,address)"(
      list?: BytesLike | null,
      account?: string | null
    ): AddressRemovedFromListEventFilter;
    AddressRemovedFromList(
      list?: BytesLike | null,
      account?: string | null
    ): AddressRemovedFromListEventFilter;

    "ConfigUpdated(bytes32,bytes32)"(
      key?: BytesLike | null,
      value?: BytesLike | null
    ): ConfigUpdatedEventFilter;
    ConfigUpdated(
      key?: BytesLike | null,
      value?: BytesLike | null
    ): ConfigUpdatedEventFilter;

    "ResetExecuted()"(): ResetExecutedEventFilter;
    ResetExecuted(): ResetExecutedEventFilter;
  };

  estimateGas: {
    addToList(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    "addToList(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    "get(bytes32)"(
      key_: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "get(bytes32[])"(
      keys_: BytesLike[],
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    governor(overrides?: CallOverrides): Promise<BigNumber>;

    "governor()"(overrides?: CallOverrides): Promise<BigNumber>;

    governorDeployer(overrides?: CallOverrides): Promise<BigNumber>;

    "governorDeployer()"(overrides?: CallOverrides): Promise<BigNumber>;

    "listContains(bytes32,address[])"(
      list_: BytesLike,
      accounts_: string[],
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "listContains(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    powerTokenDeployer(overrides?: CallOverrides): Promise<BigNumber>;

    "powerTokenDeployer()"(overrides?: CallOverrides): Promise<BigNumber>;

    removeFromList(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    "removeFromList(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    reset(overrides?: Overrides & { from?: string }): Promise<BigNumber>;

    "reset()"(overrides?: Overrides & { from?: string }): Promise<BigNumber>;

    updateConfig(
      key_: BytesLike,
      value_: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    "updateConfig(bytes32,bytes32)"(
      key_: BytesLike,
      value_: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    zeroToken(overrides?: CallOverrides): Promise<BigNumber>;

    "zeroToken()"(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    addToList(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    "addToList(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    "get(bytes32)"(
      key_: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "get(bytes32[])"(
      keys_: BytesLike[],
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    governor(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    "governor()"(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    governorDeployer(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    "governorDeployer()"(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "listContains(bytes32,address[])"(
      list_: BytesLike,
      accounts_: string[],
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "listContains(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    powerTokenDeployer(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "powerTokenDeployer()"(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    removeFromList(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    "removeFromList(bytes32,address)"(
      list_: BytesLike,
      account_: string,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    reset(
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    "reset()"(
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    updateConfig(
      key_: BytesLike,
      value_: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    "updateConfig(bytes32,bytes32)"(
      key_: BytesLike,
      value_: BytesLike,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    zeroToken(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    "zeroToken()"(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}
