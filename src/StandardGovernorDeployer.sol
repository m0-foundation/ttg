// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { ContractHelper } from "./libs/ContractHelper.sol";

import { IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";

import { StandardGovernor } from "./StandardGovernor.sol";

contract StandardGovernorDeployer is IStandardGovernorDeployer {
    address public immutable registrar;
    address public immutable vault;
    address public immutable zeroGovernor;
    address public immutable zeroToken;

    address public lastDeploy;

    uint256 public nonce;

    modifier onlyZeroGovernor() {
        if (msg.sender != zeroGovernor) revert NotZeroGovernor();

        _;
    }

    constructor(address zeroGovernor_, address registrar_, address vault_, address zeroToken_) {
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((registrar = registrar_) == address(0)) revert InvalidRegistrarAddress();
        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();
        if ((zeroToken = zeroToken_) == address(0)) revert InvalidZeroTokenAddress();
    }

    function deploy(
        address powerToken_,
        address emergencyGovernor_,
        address cashToken_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_
    ) external onlyZeroGovernor returns (address deployed_) {
        ++nonce;

        deployed_ = address(
            new StandardGovernor(
                powerToken_,
                emergencyGovernor_,
                zeroGovernor,
                cashToken_,
                registrar,
                vault,
                zeroToken,
                proposalFee_,
                maxTotalZeroRewardPerActiveEpoch_
            )
        );

        lastDeploy = deployed_;
    }

    function nextDeploy() external view returns (address nextDeploy_) {
        return ContractHelper.getContractFrom(address(this), nonce + 1);
    }
}
