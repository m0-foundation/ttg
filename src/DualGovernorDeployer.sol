// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IDualGovernorDeployer } from "./interfaces/IDualGovernorDeployer.sol";

import { DualGovernor } from "./DualGovernor.sol";
import { ContractHelper } from "./ContractHelper.sol";

contract DualGovernorDeployer is IDualGovernorDeployer {
    address public immutable registrar;
    address public immutable zeroToken;

    uint256 public nonce;

    modifier onlyRegistrar() {
        if (msg.sender != registrar) revert CallerIsNotRegistrar();

        _;
    }

    constructor(address registrar_, address zeroToken_) {
        registrar = registrar_;
        zeroToken = zeroToken_;
    }

    function deploy(
        address cashToken_,
        address powerToken_,
        uint256 proposalFee_,
        uint256 minProposalFee_,
        uint256 maxProposalFee_,
        uint256 reward_,
        uint16 powerTokenQuorumRatio_,
        uint16 zeroTokenQuorumRatio_
    ) external onlyRegistrar returns (address deployed_) {
        ++nonce;

        deployed_ = address(
            new DualGovernor(
                cashToken_,
                registrar,
                zeroToken,
                powerToken_,
                proposalFee_,
                minProposalFee_,
                maxProposalFee_,
                reward_,
                powerTokenQuorumRatio_,
                zeroTokenQuorumRatio_
            )
        );
    }

    function getNextDeploy() external view returns (address nextDeploy_) {
        nextDeploy_ = ContractHelper.getContractFrom(address(this), nonce + 1);
    }
}
