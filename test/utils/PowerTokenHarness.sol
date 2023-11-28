// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { PowerToken } from "../../src/PowerToken.sol";

contract PowerTokenHarness is PowerToken {
    constructor(
        address bootstrapToken_,
        address standardGovernor_,
        address cashToken_,
        address vault_
    ) PowerToken(bootstrapToken_, standardGovernor_, cashToken_, vault_) {}

    function setNextCashTokenStartingEpoch(uint256 nextCashTokenStartingEpoch_) external {
        _nextCashTokenStartingEpoch = nextCashTokenStartingEpoch_;
    }

    function setInternalCashToken(address cashToken_) external {
        _cashToken = cashToken_;
    }

    function setInternalNextCashToken(address nextCashToken_) external {
        _nextCashToken = nextCashToken_;
    }

    function setNextTargetSupplyStartingEpoch(uint256 nextTargetSupplyStartingEpoch_) external {
        _nextTargetSupplyStartingEpoch = nextTargetSupplyStartingEpoch_;
    }

    function setInternalTargetSupply(uint256 targetSupply_) external {
        _targetSupply = targetSupply_;
    }

    function setInternalNextTargetSupply(uint256 nextTargetSupply_) external {
        _nextTargetSupply = nextTargetSupply_;
    }

    function nextCashTokenStartingEpoch() external view returns (uint256 epoch_) {
        return _nextCashTokenStartingEpoch;
    }

    function internalCashToken() external view returns (address cashToken_) {
        return _cashToken;
    }

    function internalNextCashToken() external view returns (address nextCashToken_) {
        return _nextCashToken;
    }
}
