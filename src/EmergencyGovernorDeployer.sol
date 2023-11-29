// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { ContractHelper } from "../lib/common/src/ContractHelper.sol";

import { IEmergencyGovernorDeployer } from "./interfaces/IEmergencyGovernorDeployer.sol";

import { EmergencyGovernor } from "./EmergencyGovernor.sol";

contract EmergencyGovernorDeployer is IEmergencyGovernorDeployer {
    address public immutable registrar;
    address public immutable zeroGovernor;

    address public lastDeploy;

    uint256 public nonce;

    modifier onlyZeroGovernor() {
        if (msg.sender != zeroGovernor) revert NotZeroGovernor();

        _;
    }

    constructor(address zeroGovernor_, address registrar_) {
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((registrar = registrar_) == address(0)) revert InvalidRegistrarAddress();
    }

    function deploy(
        address powerToken_,
        address standardGovernor_,
        uint16 thresholdRatio_
    ) external onlyZeroGovernor returns (address deployed_) {
        ++nonce;

        deployed_ = address(
            new EmergencyGovernor(powerToken_, zeroGovernor, registrar, standardGovernor_, thresholdRatio_)
        );

        lastDeploy = deployed_;
    }

    function nextDeploy() external view returns (address nextDeploy_) {
        return ContractHelper.getContractFrom(address(this), nonce + 1);
    }
}
