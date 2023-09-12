// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";

import { PowerToken } from "./PowerToken.sol";
import { ContractHelper } from "./ContractHelper.sol";

contract PowerTokenDeployer is IPowerTokenDeployer {
    address public immutable registrar;
    address public immutable treasury;
    address public immutable zeroToken;

    uint256 public nonce = 1;

    modifier onlyRegistrar() {
        if (msg.sender != registrar) revert CallerIsNotRegistrar();

        _;
    }

    constructor(address registrar_, address treasury_, address zeroToken_) {
        registrar = registrar_;
        treasury = treasury_;
        zeroToken = zeroToken_;
    }

    function deploy(address governor_, address cash_) external onlyRegistrar returns (address deployed_) {
        ++nonce;

        deployed_ = address(new PowerToken(governor_, cash_, treasury, zeroToken));
    }

    function getNextDeploy() external view returns (address nextDeploy_) {
        nextDeploy_ = ContractHelper.getContractFrom(address(this), nonce);
    }
}
