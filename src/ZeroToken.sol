// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { EpochBasedVoteToken } from "./abstract/EpochBasedVoteToken.sol";

import { IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";
import { IZeroToken } from "./interfaces/IZeroToken.sol";

/**
 * @title An instance of an EpochBasedVoteToken delegating minting control to a Standard Governor, and enabling
 *        range queries for past balances, voting powers, delegations, and  total supplies.
 */
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
    ) external view returns (uint256[] memory votingPowers_) {
        _revertIfNotPastTimepoint(endEpoch_);

        return _getValuesBetween(_votingPowers[account_], startEpoch_, endEpoch_);
    }

    function pastBalancesOf(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view returns (uint256[] memory balances_) {
        _revertIfNotPastTimepoint(endEpoch_);

        return _getValuesBetween(_balances[account_], startEpoch_, endEpoch_);
    }

    function pastDelegates(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view returns (address[] memory delegatees_) {
        _revertIfNotPastTimepoint(endEpoch_);

        return _getDelegateesBetween(account_, startEpoch_, endEpoch_);
    }

    function pastTotalSupplies(
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view returns (uint256[] memory totalSupplies_) {
        _revertIfNotPastTimepoint(endEpoch_);

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

        AccountSnap[] storage accountSnaps_ = _delegatees[account_];

        uint256 snapIndex_ = accountSnaps_.length;

        // Keep going back as long as the epoch is greater or equal to the previous AccountSnap's startingEpoch.
        while (snapIndex_ > 0) {
            AccountSnap storage accountSnap_ = _unsafeAccess(accountSnaps_, --snapIndex_);

            uint256 snapStartingEpoch_ = accountSnap_.startingEpoch;

            // Keep checking if the AccountSnap's startingEpoch is applicable to the current and decrementing epoch.
            while (snapStartingEpoch_ <= endEpoch_) {
                delegatees_[--epochsIndex_] = _getDefaultIfZero(accountSnap_.account, account_);

                if (epochsIndex_ == 0) return delegatees_;

                --endEpoch_;
            }
        }

        // Set the remaining delegatee values (from before any accountSnaps existed) to the account itself.
        while (epochsIndex_ > 0) {
            delegatees_[--epochsIndex_] = account_;
        }
    }

    function _getValuesBetween(
        AmountSnap[] storage amountSnaps_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) internal view returns (uint256[] memory values_) {
        if (startEpoch_ > endEpoch_) revert StartEpochAfterEndEpoch();

        uint256 epochsIndex_ = endEpoch_ - startEpoch_ + 1;

        values_ = new uint256[](epochsIndex_);

        uint256 snapIndex_ = amountSnaps_.length;

        // Keep going back as long as the epoch is greater or equal to the previous AmountSnap's startingEpoch.
        while (snapIndex_ > 0) {
            AmountSnap storage amountSnap_ = _unsafeAccess(amountSnaps_, --snapIndex_);

            uint256 snapStartingEpoch_ = amountSnap_.startingEpoch;

            // Keep checking if the AmountSnap's startingEpoch is applicable to the current and decrementing epoch.
            while (snapStartingEpoch_ <= endEpoch_) {
                values_[--epochsIndex_] = amountSnap_.amount;

                if (epochsIndex_ == 0) return values_;

                --endEpoch_;
            }
        }
    }
}
