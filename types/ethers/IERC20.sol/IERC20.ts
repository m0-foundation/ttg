/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
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

export interface IERC20Interface extends utils.Interface {
  functions: {
    "allowance(address,address)": FunctionFragment;
    "approve(address,uint256)": FunctionFragment;
    "balanceOf(address)": FunctionFragment;
    "decimals()": FunctionFragment;
    "decreaseAllowance(address,uint256)": FunctionFragment;
    "increaseAllowance(address,uint256)": FunctionFragment;
    "name()": FunctionFragment;
    "symbol()": FunctionFragment;
    "totalSupply()": FunctionFragment;
    "transfer(address,uint256)": FunctionFragment;
    "transferFrom(address,address,uint256)": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "allowance"
      | "allowance(address,address)"
      | "approve"
      | "approve(address,uint256)"
      | "balanceOf"
      | "balanceOf(address)"
      | "decimals"
      | "decimals()"
      | "decreaseAllowance"
      | "decreaseAllowance(address,uint256)"
      | "increaseAllowance"
      | "increaseAllowance(address,uint256)"
      | "name"
      | "name()"
      | "symbol"
      | "symbol()"
      | "totalSupply"
      | "totalSupply()"
      | "transfer"
      | "transfer(address,uint256)"
      | "transferFrom"
      | "transferFrom(address,address,uint256)"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "allowance",
    values: [string, string]
  ): string;
  encodeFunctionData(
    functionFragment: "allowance(address,address)",
    values: [string, string]
  ): string;
  encodeFunctionData(
    functionFragment: "approve",
    values: [string, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "approve(address,uint256)",
    values: [string, BigNumberish]
  ): string;
  encodeFunctionData(functionFragment: "balanceOf", values: [string]): string;
  encodeFunctionData(
    functionFragment: "balanceOf(address)",
    values: [string]
  ): string;
  encodeFunctionData(functionFragment: "decimals", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "decimals()",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "decreaseAllowance",
    values: [string, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "decreaseAllowance(address,uint256)",
    values: [string, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "increaseAllowance",
    values: [string, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "increaseAllowance(address,uint256)",
    values: [string, BigNumberish]
  ): string;
  encodeFunctionData(functionFragment: "name", values?: undefined): string;
  encodeFunctionData(functionFragment: "name()", values?: undefined): string;
  encodeFunctionData(functionFragment: "symbol", values?: undefined): string;
  encodeFunctionData(functionFragment: "symbol()", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "totalSupply",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "totalSupply()",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "transfer",
    values: [string, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "transfer(address,uint256)",
    values: [string, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "transferFrom",
    values: [string, string, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "transferFrom(address,address,uint256)",
    values: [string, string, BigNumberish]
  ): string;

  decodeFunctionResult(functionFragment: "allowance", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "allowance(address,address)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "approve", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "approve(address,uint256)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "balanceOf", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "balanceOf(address)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "decimals", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "decimals()", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "decreaseAllowance",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "decreaseAllowance(address,uint256)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "increaseAllowance",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "increaseAllowance(address,uint256)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "name", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "name()", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "symbol", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "symbol()", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "totalSupply",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "totalSupply()",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "transfer", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "transfer(address,uint256)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "transferFrom",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "transferFrom(address,address,uint256)",
    data: BytesLike
  ): Result;

  events: {
    "Approval(address,address,uint256)": EventFragment;
    "Transfer(address,address,uint256)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "Approval"): EventFragment;
  getEvent(
    nameOrSignatureOrTopic: "Approval(address,address,uint256)"
  ): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Transfer"): EventFragment;
  getEvent(
    nameOrSignatureOrTopic: "Transfer(address,address,uint256)"
  ): EventFragment;
}

export interface ApprovalEventObject {
  account: string;
  spender: string;
  amount: BigNumber;
}
export type ApprovalEvent = TypedEvent<
  [string, string, BigNumber],
  ApprovalEventObject
>;

export type ApprovalEventFilter = TypedEventFilter<ApprovalEvent>;

export interface TransferEventObject {
  account: string;
  recipient: string;
  amount: BigNumber;
}
export type TransferEvent = TypedEvent<
  [string, string, BigNumber],
  TransferEventObject
>;

export type TransferEventFilter = TypedEventFilter<TransferEvent>;

export interface IERC20 extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IERC20Interface;

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
    allowance(
      account: string,
      spender: string,
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { allowance: BigNumber }>;

    "allowance(address,address)"(
      account: string,
      spender: string,
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { allowance: BigNumber }>;

    approve(
      spender: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    "approve(address,uint256)"(
      spender: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    balanceOf(
      account: string,
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { balance: BigNumber }>;

    "balanceOf(address)"(
      account: string,
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { balance: BigNumber }>;

    decimals(
      overrides?: CallOverrides
    ): Promise<[number] & { decimals: number }>;

    "decimals()"(
      overrides?: CallOverrides
    ): Promise<[number] & { decimals: number }>;

    decreaseAllowance(
      spender: string,
      subtractedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    "decreaseAllowance(address,uint256)"(
      spender: string,
      subtractedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    increaseAllowance(
      spender: string,
      addedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    "increaseAllowance(address,uint256)"(
      spender: string,
      addedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    name(overrides?: CallOverrides): Promise<[string] & { name: string }>;

    "name()"(overrides?: CallOverrides): Promise<[string] & { name: string }>;

    symbol(overrides?: CallOverrides): Promise<[string] & { symbol: string }>;

    "symbol()"(
      overrides?: CallOverrides
    ): Promise<[string] & { symbol: string }>;

    totalSupply(
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { totalSupply: BigNumber }>;

    "totalSupply()"(
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { totalSupply: BigNumber }>;

    transfer(
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    "transfer(address,uint256)"(
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    transferFrom(
      account: string,
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    "transferFrom(address,address,uint256)"(
      account: string,
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;
  };

  allowance(
    account: string,
    spender: string,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  "allowance(address,address)"(
    account: string,
    spender: string,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  approve(
    spender: string,
    amount: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  "approve(address,uint256)"(
    spender: string,
    amount: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  balanceOf(account: string, overrides?: CallOverrides): Promise<BigNumber>;

  "balanceOf(address)"(
    account: string,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  decimals(overrides?: CallOverrides): Promise<number>;

  "decimals()"(overrides?: CallOverrides): Promise<number>;

  decreaseAllowance(
    spender: string,
    subtractedAmount: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  "decreaseAllowance(address,uint256)"(
    spender: string,
    subtractedAmount: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  increaseAllowance(
    spender: string,
    addedAmount: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  "increaseAllowance(address,uint256)"(
    spender: string,
    addedAmount: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  name(overrides?: CallOverrides): Promise<string>;

  "name()"(overrides?: CallOverrides): Promise<string>;

  symbol(overrides?: CallOverrides): Promise<string>;

  "symbol()"(overrides?: CallOverrides): Promise<string>;

  totalSupply(overrides?: CallOverrides): Promise<BigNumber>;

  "totalSupply()"(overrides?: CallOverrides): Promise<BigNumber>;

  transfer(
    recipient: string,
    amount: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  "transfer(address,uint256)"(
    recipient: string,
    amount: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  transferFrom(
    account: string,
    recipient: string,
    amount: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  "transferFrom(address,address,uint256)"(
    account: string,
    recipient: string,
    amount: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  callStatic: {
    allowance(
      account: string,
      spender: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "allowance(address,address)"(
      account: string,
      spender: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    approve(
      spender: string,
      amount: BigNumberish,
      overrides?: CallOverrides
    ): Promise<boolean>;

    "approve(address,uint256)"(
      spender: string,
      amount: BigNumberish,
      overrides?: CallOverrides
    ): Promise<boolean>;

    balanceOf(account: string, overrides?: CallOverrides): Promise<BigNumber>;

    "balanceOf(address)"(
      account: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    decimals(overrides?: CallOverrides): Promise<number>;

    "decimals()"(overrides?: CallOverrides): Promise<number>;

    decreaseAllowance(
      spender: string,
      subtractedAmount: BigNumberish,
      overrides?: CallOverrides
    ): Promise<boolean>;

    "decreaseAllowance(address,uint256)"(
      spender: string,
      subtractedAmount: BigNumberish,
      overrides?: CallOverrides
    ): Promise<boolean>;

    increaseAllowance(
      spender: string,
      addedAmount: BigNumberish,
      overrides?: CallOverrides
    ): Promise<boolean>;

    "increaseAllowance(address,uint256)"(
      spender: string,
      addedAmount: BigNumberish,
      overrides?: CallOverrides
    ): Promise<boolean>;

    name(overrides?: CallOverrides): Promise<string>;

    "name()"(overrides?: CallOverrides): Promise<string>;

    symbol(overrides?: CallOverrides): Promise<string>;

    "symbol()"(overrides?: CallOverrides): Promise<string>;

    totalSupply(overrides?: CallOverrides): Promise<BigNumber>;

    "totalSupply()"(overrides?: CallOverrides): Promise<BigNumber>;

    transfer(
      recipient: string,
      amount: BigNumberish,
      overrides?: CallOverrides
    ): Promise<boolean>;

    "transfer(address,uint256)"(
      recipient: string,
      amount: BigNumberish,
      overrides?: CallOverrides
    ): Promise<boolean>;

    transferFrom(
      account: string,
      recipient: string,
      amount: BigNumberish,
      overrides?: CallOverrides
    ): Promise<boolean>;

    "transferFrom(address,address,uint256)"(
      account: string,
      recipient: string,
      amount: BigNumberish,
      overrides?: CallOverrides
    ): Promise<boolean>;
  };

  filters: {
    "Approval(address,address,uint256)"(
      account?: string | null,
      spender?: string | null,
      amount?: null
    ): ApprovalEventFilter;
    Approval(
      account?: string | null,
      spender?: string | null,
      amount?: null
    ): ApprovalEventFilter;

    "Transfer(address,address,uint256)"(
      account?: string | null,
      recipient?: string | null,
      amount?: null
    ): TransferEventFilter;
    Transfer(
      account?: string | null,
      recipient?: string | null,
      amount?: null
    ): TransferEventFilter;
  };

  estimateGas: {
    allowance(
      account: string,
      spender: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "allowance(address,address)"(
      account: string,
      spender: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    approve(
      spender: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    "approve(address,uint256)"(
      spender: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    balanceOf(account: string, overrides?: CallOverrides): Promise<BigNumber>;

    "balanceOf(address)"(
      account: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    decimals(overrides?: CallOverrides): Promise<BigNumber>;

    "decimals()"(overrides?: CallOverrides): Promise<BigNumber>;

    decreaseAllowance(
      spender: string,
      subtractedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    "decreaseAllowance(address,uint256)"(
      spender: string,
      subtractedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    increaseAllowance(
      spender: string,
      addedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    "increaseAllowance(address,uint256)"(
      spender: string,
      addedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    name(overrides?: CallOverrides): Promise<BigNumber>;

    "name()"(overrides?: CallOverrides): Promise<BigNumber>;

    symbol(overrides?: CallOverrides): Promise<BigNumber>;

    "symbol()"(overrides?: CallOverrides): Promise<BigNumber>;

    totalSupply(overrides?: CallOverrides): Promise<BigNumber>;

    "totalSupply()"(overrides?: CallOverrides): Promise<BigNumber>;

    transfer(
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    "transfer(address,uint256)"(
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    transferFrom(
      account: string,
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    "transferFrom(address,address,uint256)"(
      account: string,
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    allowance(
      account: string,
      spender: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "allowance(address,address)"(
      account: string,
      spender: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    approve(
      spender: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    "approve(address,uint256)"(
      spender: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    balanceOf(
      account: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "balanceOf(address)"(
      account: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    decimals(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    "decimals()"(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    decreaseAllowance(
      spender: string,
      subtractedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    "decreaseAllowance(address,uint256)"(
      spender: string,
      subtractedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    increaseAllowance(
      spender: string,
      addedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    "increaseAllowance(address,uint256)"(
      spender: string,
      addedAmount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    name(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    "name()"(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    symbol(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    "symbol()"(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    totalSupply(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    "totalSupply()"(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    transfer(
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    "transfer(address,uint256)"(
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    transferFrom(
      account: string,
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    "transferFrom(address,address,uint256)"(
      account: string,
      recipient: string,
      amount: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;
  };
}
