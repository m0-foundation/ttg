// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { console2 } from "../../../lib/forge-std/src/Test.sol";

import { AddressSet, LibAddressSet } from "../../utils/AddressSet.sol";
import { TestUtils } from "../../utils/TestUtils.sol";

/// @dev Because the initial holders and balances are set at deployment,
///      we need a store to share holders between the invariant and handlers.
contract HolderStore is TestUtils {
    using LibAddressSet for AddressSet;

    uint256 public constant POWER_HOLDER_NUM = 10;
    uint256 public constant ZERO_HOLDER_NUM = 10;

    uint256 public constant POWER_INITIAL_TOTAL_SUPPLY = 1_000_000;
    uint256 public constant ZERO_INITIAL_TOTAL_SUPPLY = 1_000_000_000e6;

    AddressSet internal _powerHolders;
    uint256[] internal _powerHolderBalances;

    AddressSet internal _zeroHolders;
    uint256[] internal _zeroHolderBalances;

    uint256 internal _randomAmountSeed;

    constructor() {}

    function _generateRandomAmount(address holder_, uint256 modulus_) internal returns (uint256) {
        _randomAmountSeed++;
        return uint256(keccak256(abi.encodePacked(vm.getBlockTimestamp(), holder_, _randomAmountSeed))) % modulus_;
    }

    function initActors() external {
        for (uint256 i; i < POWER_HOLDER_NUM; ++i) {
            console2.log("Init POWER holder %s", i);
            _powerHolders.add(makeAddr(string(abi.encodePacked("power_holder", i))));

            address powerHolder_ = _powerHolders.get(i);
            uint256 balance_ = _generateRandomAmount(powerHolder_, POWER_INITIAL_TOTAL_SUPPLY / POWER_HOLDER_NUM);

            _powerHolderBalances.push(balance_);
        }

        for (uint256 i = 0; i < ZERO_HOLDER_NUM; ++i) {
            console2.log("Init ZERO holder %s", i);
            _zeroHolders.add(makeAddr(string(abi.encodePacked("zero_holder", i))));

            address zeroHolder_ = _zeroHolders.get(i);
            uint256 balance_ = _generateRandomAmount(zeroHolder_, ZERO_INITIAL_TOTAL_SUPPLY / ZERO_HOLDER_NUM);

            _zeroHolderBalances.push(balance_);
        }
    }

    function powerHolders() external view returns (address[] memory) {
        return _powerHolders.addrs;
    }

    function zeroHolders() external view returns (address[] memory) {
        return _zeroHolders.addrs;
    }

    function powerHolderBalances() external view returns (uint256[] memory) {
        return _powerHolderBalances;
    }

    function zeroHolderBalances() external view returns (uint256[] memory) {
        return _zeroHolderBalances;
    }

    function getPowerHolder(uint256 powerHolderIndexSeed_) external view returns (address) {
        return _powerHolders.rand(powerHolderIndexSeed_);
    }

    function getZeroHolder(uint256 zeroHolderIndexSeed_) external view returns (address) {
        return _zeroHolders.rand(zeroHolderIndexSeed_);
    }
}
