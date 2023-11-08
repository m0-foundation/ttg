// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IERC20 } from "./interfaces/IERC20.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IZeroToken } from "./interfaces/IZeroToken.sol";

import { EpochBasedVoteToken } from "./EpochBasedVoteToken.sol";
import { PureEpochs } from "./PureEpochs.sol";

contract ZeroToken is IZeroToken, EpochBasedVoteToken {
    address internal immutable _registrar;

    modifier onlGovernor() {
        if (msg.sender != IRegistrar(_registrar).governor()) revert NotGovernor();

        _;
    }

    constructor(
        address registrar_,
        address[] memory initialAccounts_,
        uint256[] memory initialBalances_
    ) EpochBasedVoteToken("Zero Token", "ZERO", 6) {
        uint256 accountsLength_ = initialAccounts_.length;
        uint256 balancesLength_ = initialBalances_.length;

        if (accountsLength_ != balancesLength_) revert LengthMismatch(accountsLength_, balancesLength_);

        for (uint256 index_; index_ < accountsLength_; ++index_) {
            _mint(initialAccounts_[index_], initialBalances_[index_]);
        }

        _registrar = registrar_;
    }

    function mint(address recipient_, uint256 amount_) external onlGovernor {
        _mint(recipient_, amount_);
    }

    function registrar() external view returns (address registrar_) {
        return _registrar;
    }
}
