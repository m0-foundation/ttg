/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type {
  MockCashToken,
  MockCashTokenInterface,
} from "../../Mocks.sol/MockCashToken";

const _abi = [
  {
    inputs: [
      {
        internalType: "bool",
        name: "transferFromSuccess_",
        type: "bool",
      },
    ],
    name: "setTransferFromSuccess",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender_",
        type: "address",
      },
      {
        internalType: "address",
        name: "recipient_",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount_",
        type: "uint256",
      },
    ],
    name: "transferFrom",
    outputs: [
      {
        internalType: "bool",
        name: "success_",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

const _bytecode =
  "0x608060405234801561001057600080fd5b5061016f806100206000396000f3fe608060405234801561001057600080fd5b50600436106100365760003560e01c806323b872dd1461003b578063da5c69001461006a575b600080fd5b6100566100493660046100d4565b505060005460ff16919050565b604051901515815260200160405180910390f35b6100a9610078366004610110565b600080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016911515919091179055565b005b803573ffffffffffffffffffffffffffffffffffffffff811681146100cf57600080fd5b919050565b6000806000606084860312156100e957600080fd5b6100f2846100ab565b9250610100602085016100ab565b9150604084013590509250925092565b60006020828403121561012257600080fd5b8135801515811461013257600080fd5b939250505056fea264697066735822122069575f0996eb8bcb4b42c5b4b166a9b7fa59f93863a14c097f40d08a5116360564736f6c63430008130033";

type MockCashTokenConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: MockCashTokenConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class MockCashToken__factory extends ContractFactory {
  constructor(...args: MockCashTokenConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    overrides?: Overrides & { from?: string }
  ): Promise<MockCashToken> {
    return super.deploy(overrides || {}) as Promise<MockCashToken>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: string }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): MockCashToken {
    return super.attach(address) as MockCashToken;
  }
  override connect(signer: Signer): MockCashToken__factory {
    return super.connect(signer) as MockCashToken__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): MockCashTokenInterface {
    return new utils.Interface(_abi) as MockCashTokenInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): MockCashToken {
    return new Contract(address, _abi, signerOrProvider) as MockCashToken;
  }
}
