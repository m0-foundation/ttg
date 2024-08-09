// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { ContractHelper } from "../lib/common/src/ContractHelper.sol";

import { Registrar } from "../src/Registrar.sol";

contract DeployBase {
    /**
     * @dev    Deploys the Registrar contract.
     * @param  portal_    The address of the Portal contract.
     * @return registrar_ The address of the deployed Registrar contract.
     */
    function deploy(address portal_) public virtual returns (address registrar_) {
        return address(new Registrar(portal_));
    }

    function _getExpectedRegistrar(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_);
    }

    function getExpectedRegistrar(address deployer_, uint256 deployerNonce_) public pure virtual returns (address) {
        return _getExpectedRegistrar(deployer_, deployerNonce_);
    }

    function getDeployerNonceAfterTTGDeployment(uint256 deployerNonce_) public pure virtual returns (uint256) {
        return deployerNonce_ + 1;
    }
}
