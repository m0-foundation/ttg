// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import { ContractHelper } from "./libs/ContractHelper.sol";

import { IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";

import { PowerToken } from "./PowerToken.sol";

contract PowerTokenDeployer is IPowerTokenDeployer {
    address public immutable vault;
    address public immutable zeroGovernor;

    address public lastDeploy;

    uint256 public nonce;

    modifier onlyZeroGovernor() {
        if (msg.sender != zeroGovernor) revert NotZeroGovernor();

        _;
    }

    constructor(address zeroGovernor_, address vault_) {
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();
    }

    function deploy(
        address bootstrapToken_,
        address standardGovernor_,
        address cashToken_
    ) external onlyZeroGovernor returns (address deployed_) {
        ++nonce;

        deployed_ = address(new PowerToken(bootstrapToken_, standardGovernor_, cashToken_, vault));

        lastDeploy = deployed_;
    }

    function nextDeploy() external view returns (address nextDeploy_) {
        return ContractHelper.getContractFrom(address(this), nonce + 1);
    }
}
