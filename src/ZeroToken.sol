// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { UIntMath } from "../lib/common/src/libs/UIntMath.sol";

import { EpochBasedVoteToken } from "./abstract/EpochBasedVoteToken.sol";

import { IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";
import { IZeroToken } from "./interfaces/IZeroToken.sol";

/*

███████╗███████╗██████╗  ██████╗     ████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗
╚══███╔╝██╔════╝██╔══██╗██╔═══██╗    ╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║
  ███╔╝ █████╗  ██████╔╝██║   ██║       ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║
 ███╔╝  ██╔══╝  ██╔══██╗██║   ██║       ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║
███████╗███████╗██║  ██║╚██████╔╝       ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║
╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝        ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝
                                                                                 

*/

/**
 * @title  An instance of an EpochBasedVoteToken delegating minting control to a Standard Governor,
 *         and enabling range queries for past balances, voting powers, delegations, and  total supplies.
 * @author M^0 Labs
 */
contract ZeroToken is IZeroToken, EpochBasedVoteToken {
    /* ============ Variables ============ */

    /// @inheritdoc IZeroToken
    address public immutable standardGovernorDeployer;

    /* ============ Modifiers ============ */

    /// @dev Revert if the caller is not the Standard Governor.
    modifier onlyStandardGovernor() {
        if (msg.sender != standardGovernor()) revert NotStandardGovernor();
        _;
    }

    /* ============ Constructor ============ */

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

        if (accountsLength_ != balancesLength_) revert ArrayLengthMismatch(accountsLength_, balancesLength_);

        for (uint256 index_; index_ < accountsLength_; ++index_) {
            _mint(initialAccounts_[index_], initialBalances_[index_]);
        }
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IZeroToken
    function mint(address recipient_, uint256 amount_) external onlyStandardGovernor {
        _mint(recipient_, amount_);
    }

    /* ============ View/Pure Functions ============ */

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
    function pastTotalSupplies(uint256 startEpoch_, uint256 endEpoch_) external view returns (uint256[] memory) {
        uint16 safeEndEpoch_ = UIntMath.safe16(endEpoch_);

        _revertIfNotPastTimepoint(safeEndEpoch_);

        return _getValuesBetween(_totalSupplies, UIntMath.safe16(startEpoch_), safeEndEpoch_);
    }

    /// @inheritdoc IZeroToken
    function standardGovernor() public view returns (address) {
        return IStandardGovernorDeployer(standardGovernorDeployer).lastDeploy();
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev    Returns the values of `amountSnaps_` between `startEpoch_` and `endEpoch_`.
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
        if (startEpoch_ == 0) revert EpochZero();
        if (startEpoch_ > endEpoch_) revert StartEpochAfterEndEpoch();

        uint16 epochsIndex_ = endEpoch_ - startEpoch_ + 1;

        values_ = new uint256[](epochsIndex_);

        uint256 snapIndex_ = amountSnaps_.length;

        // Keep going back as long as the epoch is greater or equal to the previous AmountSnap's startingEpoch.
        while (snapIndex_ > 0) {
            unchecked {
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
}
