// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { console } from "../lib/forge-std/src/console.sol";
import { Script } from "../lib/forge-std/src/Script.sol";

import { ContractHelper } from "../lib/common/src/ContractHelper.sol";
import { AdminControlledRegistrar } from "../src/AdminControlledRegistrar.sol";

/// @dev Deploy AdminControlledRegistrar on Sepolia at specific nonce to match Mainnet deployment address
contract DeployAdminControlledRegistrar is Script {
    uint64 internal constant _REGISTRAR_NONCE = 7;
    address internal constant _ADMIN = 0x12b1A4226ba7D9Ad492779c924b0fC00BDCb6217;
    address internal constant _VAULT = 0x3dc71Be52d6D687e21FC0d4FFc196F32cacbc26d;
    address internal constant _EXPECTED_ADDRESS = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;

    error DeployerNonceTooHigh(uint64 expected, uint64 actual);
    error ExpectedAddressMismatch(address expected, address actual);

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        console.log("Deployer ", deployer_);

        vm.startBroadcast(deployer_);

        uint64 deployerNonce_ = vm.getNonce(deployer_);

        if (deployerNonce_ > _REGISTRAR_NONCE) {
            revert DeployerNonceTooHigh(_REGISTRAR_NONCE, deployerNonce_);
        }

        _burnNonces(deployer_, deployerNonce_, _REGISTRAR_NONCE);

        deployerNonce_ = vm.getNonce(deployer_);
        if (deployerNonce_ != _REGISTRAR_NONCE) {
            revert DeployerNonceTooHigh(_REGISTRAR_NONCE, deployerNonce_);
        }

        AdminControlledRegistrar registrar_ = new AdminControlledRegistrar(_ADMIN, _VAULT);

        if (_EXPECTED_ADDRESS != address(registrar_)) {
            revert ExpectedAddressMismatch(_EXPECTED_ADDRESS, address(registrar_));
        }

        vm.stopBroadcast();

        console.log("Registrar", address(registrar_));
        console.log("Admin    ", registrar_.admin());
        console.log("Vault    ", registrar_.vault());
    }

    function _burnNonces(address account_, uint64 startingNonce_, uint64 targetNonce_) private {
        for (uint64 i_; i_ < targetNonce_ - startingNonce_; ++i_) {
            payable(account_).transfer(0);
        }
    }
}
