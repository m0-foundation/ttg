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

    uint256 public nonce;

    modifier onlyRegistrar() {
        if (msg.sender != registrar) revert CallerIsNotRegistrar();

        _;
    }

    constructor(address registrar_, address vault_, address zeroGovernor_, address zeroToken_) {
        if ((registrar = registrar_) == address(0)) revert InvalidRegistrarAddress();
        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((zeroToken = zeroToken_) == address(0)) revert InvalidZeroTokenAddress();
    }

    function deploy(
        address powerToken_,
        address emergencyGovernor_,
        address cashToken_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_
    ) external onlyRegistrar returns (address deployed_) {
        ++nonce;

        return
            address(
                new StandardGovernor(
                    registrar,
                    powerToken_,
                    emergencyGovernor_,
                    zeroGovernor,
                    zeroToken,
                    cashToken_,
                    vault,
                    proposalFee_,
                    maxTotalZeroRewardPerActiveEpoch_
                )
            );
    }

    function nextDeploy() external view returns (address nextDeploy_) {
        return ContractHelper.getContractFrom(address(this), nonce + 1);
    }
}
