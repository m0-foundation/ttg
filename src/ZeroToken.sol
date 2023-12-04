// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { EpochBasedVoteToken } from "./abstract/EpochBasedVoteToken.sol";

import { IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";
import { IZeroToken } from "./interfaces/IZeroToken.sol";

contract ZeroToken is IZeroToken, EpochBasedVoteToken {
    address public immutable standardGovernorDeployer;

    modifier onlyStandardGovernor() {
        if (msg.sender != standardGovernor()) revert NotStandardGovernor();

        _;
    }

    constructor(
        address standardGovernorDeployer_,
        address[] memory initialAccounts_,
        uint256[] memory initialBalances_
    ) EpochBasedVoteToken("Zero Token", "ZERO", 6) {
        if ((standardGovernorDeployer = standardGovernorDeployer_) == address(0)) {
            revert InvalidStandardGovernorDeployerAddress();
        }

        uint256 accountsLength_ = initialAccounts_.length;
        uint256 balancesLength_ = initialBalances_.length;

        if (accountsLength_ != balancesLength_) revert LengthMismatch(accountsLength_, balancesLength_);

        for (uint256 index_; index_ < accountsLength_; ++index_) {
            _mint(initialAccounts_[index_], initialBalances_[index_]);
        }
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function mint(address recipient_, uint256 amount_) external onlyStandardGovernor {
        _mint(recipient_, amount_);
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function getPastVotes(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view virtual returns (uint256[] memory votingPowers_) {
        _revertIfNotPastEpoch(endEpoch_);

        return _getValuesBetween(_votingPowers[account_], startEpoch_, endEpoch_);
    }

    function pastBalancesOf(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view virtual returns (uint256[] memory balances_) {
        _revertIfNotPastEpoch(endEpoch_);

        return _getValuesBetween(_balances[account_], startEpoch_, endEpoch_);
    }

    function pastDelegates(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view returns (address[] memory delegatees_) {
        _revertIfNotPastEpoch(endEpoch_);

        return _getDelegateesBetween(account_, startEpoch_, endEpoch_);
    }

    function pastTotalSupplies(
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view virtual returns (uint256[] memory totalSupplies_) {
        _revertIfNotPastEpoch(endEpoch_);

        return _getValuesBetween(_totalSupplies, startEpoch_, endEpoch_);
    }

    function standardGovernor() public view returns (address standardGovernor_) {
        return IStandardGovernorDeployer(standardGovernorDeployer).lastDeploy();
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _getDelegateesBetween(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) internal view returns (address[] memory delegatees_) {
        if (startEpoch_ > endEpoch_) revert StartEpochAfterEndEpoch();

        uint256 epochsIndex_ = endEpoch_ - startEpoch_ + 1;

        delegatees_ = new address[](epochsIndex_);

        AccountWindow[] storage accountWindows_ = _delegatees[account_];

        uint256 windowIndex_ = accountWindows_.length;

        // Keep going back as long as the epoch is greater or equal to the previous AccountWindow's startingEpoch.
        while (windowIndex_ > 0) {
            AccountWindow storage accountWindow_ = _unsafeAccountWindowAccess(accountWindows_, --windowIndex_);

            uint256 accountWindowStartingEpoch_ = accountWindow_.startingEpoch;

            // Keep checking if the AccountWindow's startingEpoch is applicable to the current and decrementing epoch.
            while (accountWindowStartingEpoch_ <= endEpoch_) {
                delegatees_[--epochsIndex_] = _getDefaultIfZero(accountWindow_.account, account_);

                if (epochsIndex_ == 0) return delegatees_;

                --endEpoch_;
            }
        }

        // Set the remaining delegatee values (from before any accountWindows existed) to the account itself.
        while (epochsIndex_ > 0) {
            delegatees_[--epochsIndex_] = account_;
        }
    }

    function _getValuesBetween(
        AmountWindow[] storage amountWindows_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) internal view returns (uint256[] memory values_) {
        if (startEpoch_ > endEpoch_) revert StartEpochAfterEndEpoch();

        uint256 epochsIndex_ = endEpoch_ - startEpoch_ + 1;

        values_ = new uint256[](epochsIndex_);

        uint256 windowIndex_ = amountWindows_.length;

        // Keep going back as long as the epoch is greater or equal to the previous AmountWindow's startingEpoch.
        while (windowIndex_ > 0) {
            AmountWindow storage amountWindow_ = _unsafeAmountWindowAccess(amountWindows_, --windowIndex_);

            uint256 amountWindowStartingEpoch_ = amountWindow_.startingEpoch;

            // Keep checking if the AmountWindow's startingEpoch is applicable to the current and decrementing epoch.
            while (amountWindowStartingEpoch_ <= endEpoch_) {
                values_[--epochsIndex_] = amountWindow_.amount;

                if (epochsIndex_ == 0) return values_;

                --endEpoch_;
            }
        }
    }
}
