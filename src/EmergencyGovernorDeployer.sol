// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IEmergencyGovernorDeployer } from "./interfaces/IEmergencyGovernorDeployer.sol";

import { ContractHelper } from "./ContractHelper.sol";
import { EmergencyGovernor } from "./EmergencyGovernor.sol";

contract EmergencyGovernorDeployer is IEmergencyGovernorDeployer {
    address public immutable registrar;
    address public immutable zeroGovernor;

    uint256 public nonce;

    modifier onlyRegistrar() {
        if (msg.sender != registrar) revert CallerIsNotRegistrar();

        _;
    }

    constructor(address registrar_, address zeroGovernor_) {
        if ((registrar = registrar_) == address(0)) revert InvalidRegistrarAddress();
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
    }

    function deploy(
        address voteToken_,
        address standardGovernor_,
        uint16 thresholdRatio_
    ) external onlyRegistrar returns (address deployed_) {
        ++nonce;

        return address(new EmergencyGovernor(registrar, voteToken_, standardGovernor_, zeroGovernor, thresholdRatio_));
    }

    function getNextDeploy() external view returns (address nextDeploy_) {
        return ContractHelper.getContractFrom(address(this), nonce + 1);
    }
}
