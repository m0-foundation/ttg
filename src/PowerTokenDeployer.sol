// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import { ContractHelper } from "./libs/ContractHelper.sol";

import { IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";

import { PowerToken } from "./PowerToken.sol";

contract PowerTokenDeployer is IPowerTokenDeployer {
    address public immutable registrar;
    address public immutable vault;

    uint256 public nonce;

    modifier onlyRegistrar() {
        if (msg.sender != registrar) revert CallerIsNotRegistrar();

        _;
    }

    constructor(address registrar_, address vault_) {
        if ((registrar = registrar_) == address(0)) revert InvalidRegistrarAddress();
        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();
    }

    function deploy(
        address governor_,
        address cashToken_,
        address bootstrapToken_
    ) external onlyRegistrar returns (address deployed_) {
        ++nonce;

        return address(new PowerToken(governor_, cashToken_, vault, bootstrapToken_));
    }

    function getNextDeploy() external view returns (address nextDeploy_) {
        return ContractHelper.getContractFrom(address(this), nonce + 1);
    }
}
