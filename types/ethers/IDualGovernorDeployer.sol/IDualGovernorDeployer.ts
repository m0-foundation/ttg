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
import type { FunctionFragment, Result } from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
} from "../common";

export interface IDualGovernorDeployerInterface extends utils.Interface {
  functions: {
    "deploy(address,address,uint256,uint256,uint256,uint256,uint16,uint16)": FunctionFragment;
    "getNextDeploy()": FunctionFragment;
    "registrar()": FunctionFragment;
    "zeroToken()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "deploy"
      | "deploy(address,address,uint256,uint256,uint256,uint256,uint16,uint16)"
      | "getNextDeploy"
      | "getNextDeploy()"
      | "registrar"
      | "registrar()"
      | "zeroToken"
      | "zeroToken()"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "deploy",
    values: [
      string,
      string,
      BigNumberish,
      BigNumberish,
      BigNumberish,
      BigNumberish,
      BigNumberish,
      BigNumberish
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "deploy(address,address,uint256,uint256,uint256,uint256,uint16,uint16)",
    values: [
      string,
      string,
      BigNumberish,
      BigNumberish,
      BigNumberish,
      BigNumberish,
      BigNumberish,
      BigNumberish
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "getNextDeploy",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "getNextDeploy()",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "registrar", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "registrar()",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "zeroToken", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "zeroToken()",
    values?: undefined
  ): string;

  decodeFunctionResult(functionFragment: "deploy", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "deploy(address,address,uint256,uint256,uint256,uint256,uint16,uint16)",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getNextDeploy",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getNextDeploy()",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "registrar", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "registrar()",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "zeroToken", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "zeroToken()",
    data: BytesLike
  ): Result;

  events: {};
}

export interface IDualGovernorDeployer extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IDualGovernorDeployerInterface;

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
    deploy(
      cashToken: string,
      powerToken: string,
      proposalFee: BigNumberish,
      minProposalFee: BigNumberish,
      maxProposalFee: BigNumberish,
      reward: BigNumberish,
      zeroTokenQuorumRatio: BigNumberish,
      powerTokenQuorumRatio: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    "deploy(address,address,uint256,uint256,uint256,uint256,uint16,uint16)"(
      cashToken: string,
      powerToken: string,
      proposalFee: BigNumberish,
      minProposalFee: BigNumberish,
      maxProposalFee: BigNumberish,
      reward: BigNumberish,
      zeroTokenQuorumRatio: BigNumberish,
      powerTokenQuorumRatio: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<ContractTransaction>;

    getNextDeploy(
      overrides?: CallOverrides
    ): Promise<[string] & { nextDeploy: string }>;

    "getNextDeploy()"(
      overrides?: CallOverrides
    ): Promise<[string] & { nextDeploy: string }>;

    registrar(
      overrides?: CallOverrides
    ): Promise<[string] & { registrar: string }>;

    "registrar()"(
      overrides?: CallOverrides
    ): Promise<[string] & { registrar: string }>;

    zeroToken(
      overrides?: CallOverrides
    ): Promise<[string] & { zeroToken: string }>;

    "zeroToken()"(
      overrides?: CallOverrides
    ): Promise<[string] & { zeroToken: string }>;
  };

  deploy(
    cashToken: string,
    powerToken: string,
    proposalFee: BigNumberish,
    minProposalFee: BigNumberish,
    maxProposalFee: BigNumberish,
    reward: BigNumberish,
    zeroTokenQuorumRatio: BigNumberish,
    powerTokenQuorumRatio: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  "deploy(address,address,uint256,uint256,uint256,uint256,uint16,uint16)"(
    cashToken: string,
    powerToken: string,
    proposalFee: BigNumberish,
    minProposalFee: BigNumberish,
    maxProposalFee: BigNumberish,
    reward: BigNumberish,
    zeroTokenQuorumRatio: BigNumberish,
    powerTokenQuorumRatio: BigNumberish,
    overrides?: Overrides & { from?: string }
  ): Promise<ContractTransaction>;

  getNextDeploy(overrides?: CallOverrides): Promise<string>;

  "getNextDeploy()"(overrides?: CallOverrides): Promise<string>;

  registrar(overrides?: CallOverrides): Promise<string>;

  "registrar()"(overrides?: CallOverrides): Promise<string>;

  zeroToken(overrides?: CallOverrides): Promise<string>;

  "zeroToken()"(overrides?: CallOverrides): Promise<string>;

  callStatic: {
    deploy(
      cashToken: string,
      powerToken: string,
      proposalFee: BigNumberish,
      minProposalFee: BigNumberish,
      maxProposalFee: BigNumberish,
      reward: BigNumberish,
      zeroTokenQuorumRatio: BigNumberish,
      powerTokenQuorumRatio: BigNumberish,
      overrides?: CallOverrides
    ): Promise<string>;

    "deploy(address,address,uint256,uint256,uint256,uint256,uint16,uint16)"(
      cashToken: string,
      powerToken: string,
      proposalFee: BigNumberish,
      minProposalFee: BigNumberish,
      maxProposalFee: BigNumberish,
      reward: BigNumberish,
      zeroTokenQuorumRatio: BigNumberish,
      powerTokenQuorumRatio: BigNumberish,
      overrides?: CallOverrides
    ): Promise<string>;

    getNextDeploy(overrides?: CallOverrides): Promise<string>;

    "getNextDeploy()"(overrides?: CallOverrides): Promise<string>;

    registrar(overrides?: CallOverrides): Promise<string>;

    "registrar()"(overrides?: CallOverrides): Promise<string>;

    zeroToken(overrides?: CallOverrides): Promise<string>;

    "zeroToken()"(overrides?: CallOverrides): Promise<string>;
  };

  filters: {};

  estimateGas: {
    deploy(
      cashToken: string,
      powerToken: string,
      proposalFee: BigNumberish,
      minProposalFee: BigNumberish,
      maxProposalFee: BigNumberish,
      reward: BigNumberish,
      zeroTokenQuorumRatio: BigNumberish,
      powerTokenQuorumRatio: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    "deploy(address,address,uint256,uint256,uint256,uint256,uint16,uint16)"(
      cashToken: string,
      powerToken: string,
      proposalFee: BigNumberish,
      minProposalFee: BigNumberish,
      maxProposalFee: BigNumberish,
      reward: BigNumberish,
      zeroTokenQuorumRatio: BigNumberish,
      powerTokenQuorumRatio: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<BigNumber>;

    getNextDeploy(overrides?: CallOverrides): Promise<BigNumber>;

    "getNextDeploy()"(overrides?: CallOverrides): Promise<BigNumber>;

    registrar(overrides?: CallOverrides): Promise<BigNumber>;

    "registrar()"(overrides?: CallOverrides): Promise<BigNumber>;

    zeroToken(overrides?: CallOverrides): Promise<BigNumber>;

    "zeroToken()"(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    deploy(
      cashToken: string,
      powerToken: string,
      proposalFee: BigNumberish,
      minProposalFee: BigNumberish,
      maxProposalFee: BigNumberish,
      reward: BigNumberish,
      zeroTokenQuorumRatio: BigNumberish,
      powerTokenQuorumRatio: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    "deploy(address,address,uint256,uint256,uint256,uint256,uint16,uint16)"(
      cashToken: string,
      powerToken: string,
      proposalFee: BigNumberish,
      minProposalFee: BigNumberish,
      maxProposalFee: BigNumberish,
      reward: BigNumberish,
      zeroTokenQuorumRatio: BigNumberish,
      powerTokenQuorumRatio: BigNumberish,
      overrides?: Overrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    getNextDeploy(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    "getNextDeploy()"(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    registrar(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    "registrar()"(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    zeroToken(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    "zeroToken()"(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}
