// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { UIntMath } from "../lib/common/src/libs/UIntMath.sol";

import { EpochBasedVoteToken } from "./abstract/EpochBasedVoteToken.sol";

import { IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";
import { IZeroToken } from "./interfaces/IZeroToken.sol";

/**
 * @title An instance of an EpochBasedVoteToken delegating minting control to a Standard Governor, and enabling
 *        range queries for past balances, voting powers, delegations, and  total supplies.
 */
contract ZeroToken is IZeroToken, EpochBasedVoteToken {
    /// @inheritdoc IZeroToken
    address public immutable standardGovernorDeployer;

    /// @dev Revert if the caller is not the Standard Governor.
    modifier onlyStandardGovernor() {
        if (msg.sender != standardGovernor()) revert NotStandardGovernor();
        _;
    }

    /**
     * @notice Constructs a new ZeroToken contract.
     * @param  standardGovernorDeployer_ The address of the StandardGovernorDeployer contract.
     * @param  initialAccounts_          The addresses of the accounts to mint tokens to.
     * @param  initialBalances_          The amounts of tokens to mint to the accounts.
     */
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

    /// @inheritdoc IZeroToken
    function mint(address recipient_, uint256 amount_) external onlyStandardGovernor {
        _mint(recipient_, amount_);
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    /// @inheritdoc IZeroToken
    function getPastVotes(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view returns (uint256[] memory) {
        uint16 safeEndEpoch_ = UIntMath.safe16(endEpoch_);

        _revertIfNotPastTimepoint(safeEndEpoch_);

        return _getValuesBetween(_votingPowers[account_], UIntMath.safe16(startEpoch_), safeEndEpoch_);
    }

    /// @inheritdoc IZeroToken
    function pastBalancesOf(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view returns (uint256[] memory) {
        uint16 safeEndEpoch_ = UIntMath.safe16(endEpoch_);

        _revertIfNotPastTimepoint(safeEndEpoch_);

        return _getValuesBetween(_balances[account_], UIntMath.safe16(startEpoch_), safeEndEpoch_);
    }

    /// @inheritdoc IZeroToken
    function pastDelegates(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view returns (address[] memory) {
        uint16 safeEndEpoch_ = UIntMath.safe16(endEpoch_);

        _revertIfNotPastTimepoint(safeEndEpoch_);

        return _getDelegateesBetween(account_, UIntMath.safe16(startEpoch_), safeEndEpoch_);
    }

    /// @inheritdoc IZeroToken
    function pastTotalSupplies(uint256 startEpoch_, uint256 endEpoch_) external view returns (uint256[] memory) {
        uint16 safeEndEpoch_ = UIntMath.safe16(endEpoch_);

        _revertIfNotPastTimepoint(safeEndEpoch_);

        return _getValuesBetween(_totalSupplies, UIntMath.safe16(startEpoch_), safeEndEpoch_);
    }

    /// @inheritdoc IZeroToken
    function standardGovernor() public view returns (address) {
        return IStandardGovernorDeployer(standardGovernorDeployer).lastDeploy();
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    /**
     * @notice Returns the delegatees of `account_` between `startEpoch_` and `endEpoch_`.
     * @param  account_    The address of the account whose delegatees are being queried.
     * @param  startEpoch_ The epoch from which to start querying.
     * @param  endEpoch_   The epoch at which to stop querying.
     * @return delegatees_ The delegatees of `account_` between `startEpoch_` and `endEpoch_`.
     */
    function _getDelegateesBetween(
        address account_,
        uint16 startEpoch_,
        uint16 endEpoch_
    ) internal view returns (address[] memory delegatees_) {
        if (startEpoch_ > endEpoch_) revert StartEpochAfterEndEpoch();

        uint16 epochsIndex_ = endEpoch_ - startEpoch_ + 1;

        delegatees_ = new address[](epochsIndex_);

        AccountSnap[] storage accountSnaps_ = _delegatees[account_];

        uint256 snapIndex_ = accountSnaps_.length;

        // Keep going back as long as the epoch is greater or equal to the previous AccountSnap's startingEpoch.
        while (snapIndex_ > 0) {
            unchecked {
                --snapIndex_;
            }

            AccountSnap storage accountSnap_ = _unsafeAccess(accountSnaps_, snapIndex_);
            uint16 snapStartingEpoch_ = accountSnap_.startingEpoch;

            // Keep checking if the AccountSnap's startingEpoch is applicable to the current and decrementing epoch.
            while (snapStartingEpoch_ <= endEpoch_) {
                unchecked {
                    --epochsIndex_;
                }

                delegatees_[epochsIndex_] = _getDefaultIfZero(accountSnap_.account, account_);

                if (epochsIndex_ == 0) return delegatees_;

                unchecked {
                    --endEpoch_;
                }
            }
        }

        // Set the remaining delegatee values (from before any accountSnaps existed) to the account itself.
        while (epochsIndex_ > 0) {
            unchecked {
                delegatees_[--epochsIndex_] = account_;
            }
        }
    }

    /**
     * @notice Returns the values of `amountSnaps_` between `startEpoch_` and `endEpoch_`.
     * @param  amountSnaps_ The array of AmountSnaps to query.
     * @param  startEpoch_  The epoch from which to start querying.
     * @param  endEpoch_    The epoch at which to stop querying.
     * @return values_      The values of `amountSnaps_` between `startEpoch_` and `endEpoch_`.
     */
    function _getValuesBetween(
        AmountSnap[] storage amountSnaps_,
        uint16 startEpoch_,
        uint16 endEpoch_
    ) internal view returns (uint256[] memory values_) {
        if (startEpoch_ > endEpoch_) revert StartEpochAfterEndEpoch();

        uint16 epochsIndex_ = endEpoch_ - startEpoch_ + 1;

        values_ = new uint256[](epochsIndex_);

        uint256 snapIndex_ = amountSnaps_.length;

        // Keep going back as long as the epoch is greater or equal to the previous AmountSnap's startingEpoch.
        while (snapIndex_ > 0) {
            unchecked {
                --snapIndex_;
            }

            AmountSnap storage amountSnap_ = _unsafeAccess(amountSnaps_, snapIndex_);

            uint256 snapStartingEpoch_ = amountSnap_.startingEpoch;

            // Keep checking if the AmountSnap's startingEpoch is applicable to the current and decrementing epoch.
            while (snapStartingEpoch_ <= endEpoch_) {
                unchecked {
                    --epochsIndex_;
                }

                values_[epochsIndex_] = amountSnap_.amount;

                if (epochsIndex_ == 0) return values_;

                unchecked {
                    --endEpoch_;
                }
            }
        }
    }
}
