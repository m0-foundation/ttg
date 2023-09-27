// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import { IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";

import { PowerToken } from "./PowerToken.sol";
import { ContractHelper } from "./ContractHelper.sol";

contract PowerTokenDeployer is IPowerTokenDeployer {
    address public immutable registrar;
    address public immutable treasury;

    uint256 public nonce;

    modifier onlyRegistrar() {
        if (msg.sender != registrar) revert CallerIsNotRegistrar();

        _;
    }

    constructor(address registrar_, address treasury_) {
        registrar = registrar_;
        treasury = treasury_;
    }

    function deploy(
        address governor_,
        address cashToken_,
        address bootstrapToken_
    ) external onlyRegistrar returns (address deployed_) {
        ++nonce;

        deployed_ = address(new PowerToken(governor_, cashToken_, treasury, bootstrapToken_));
    }

    function getNextDeploy() external view returns (address nextDeploy_) {
        nextDeploy_ = ContractHelper.getContractFrom(address(this), nonce + 1);
    }
}
