// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { StatefulERC712 } from "../lib/common/src/StatefulERC712.sol";

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { PureEpochs } from "./libs/PureEpochs.sol";

import { IERC6372 } from "./abstract/interfaces/IERC6372.sol";

import { IZeroToken } from "./interfaces/IZeroToken.sol";
import { IDistributionVault } from "./interfaces/IDistributionVault.sol";

/// @title A contract enabling pro rata distribution of arbitrary tokens to holders of the Zero Token.
contract DistributionVault is IDistributionVault, StatefulERC712 {
    /**
     * @dev The scale to apply when accumulating an account's claimable token, per epoch, before dividing.
     *      It is arbitrarily set to `1e9`. The smaller it is, the more dust will accumulate in the contract.
     *      Conversely, the larger it is, the more likely it is to overflow when accumulating.
     *      The more epochs that are claimed at once, the less dust will remain.
     */
    uint256 internal constant _GRANULARITY = 1e9;

    // keccak256("Claim(address token,uint256 startEpoch,uint256 endEpoch,address destination,uint256 nonce,uint256 deadline)")
    /// @inheritdoc IDistributionVault
    bytes32 public constant CLAIM_TYPEHASH = 0x8ef9cf97bc3ef1919633bb182b1a99bc91c2fa874c3ae8681d86bbffd5539a84;

    /// @inheritdoc IDistributionVault
    address public immutable zeroToken;

    mapping(address token => uint256 balance) internal _lastTokenBalances;

    /// @inheritdoc IDistributionVault
    mapping(address token => mapping(uint256 epoch => uint256 amount)) public distributionOfAt;

    /// @inheritdoc IDistributionVault
    mapping(address token => mapping(uint256 epoch => mapping(address account => bool claimed))) public hasClaimed;

    /**
     * @notice Constructs a new DistributionVault contract.
     * @param  zeroToken_ The address of the Zero Token contract.
     */
    constructor(address zeroToken_) StatefulERC712("DistributionVault") {
        if ((zeroToken = zeroToken_) == address(0)) revert InvalidZeroTokenAddress();
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    /// @inheritdoc IDistributionVault
    function claim(
        address token_,
        uint256 startEpoch_,
        uint256 endEpoch_,
        address destination_
    ) external returns (uint256) {
        return _claim(msg.sender, token_, startEpoch_, endEpoch_, destination_);
    }

    /// @inheritdoc IDistributionVault
    function claimBySig(
        address account_,
        address token_,
        uint256 startEpoch_,
        uint256 endEpoch_,
        address destination_,
        uint256 deadline_,
        bytes memory signature_
    ) external returns (uint256) {
        uint256 currentNonce_ = nonces[account_];
        bytes32 digest_ = getClaimDigest(token_, startEpoch_, endEpoch_, destination_, currentNonce_, deadline_);

        _revertIfInvalidSignature(account_, digest_, signature_);
        _revertIfExpired(deadline_);

        unchecked {
            nonces[account_] = currentNonce_ + 1; // Nonce realistically cannot overflow.
        }

        return _claim(account_, token_, startEpoch_, endEpoch_, destination_);
    }

    /// @inheritdoc IDistributionVault
    function distribute(address token_) external returns (uint256 amount_) {
        uint256 currentEpoch_ = clock();
        uint256 lastTokenBalance_ = _lastTokenBalances[token_];

        // Determine the additional balance of `token_` that is not accounted for in `lastTokenBalance_`.
        amount_ = IERC20(token_).balanceOf(address(this)) - lastTokenBalance_;

        emit Distribution(token_, currentEpoch_, amount_);

        distributionOfAt[token_][currentEpoch_] += amount_; // Add the amount to the distribution for the current epoch.
        _lastTokenBalances[token_] = lastTokenBalance_ + amount_; // Track this contract's latest balance of `token_`.
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    /// @inheritdoc IDistributionVault
    function name() external view returns (string memory) {
        return _name;
    }

    /// @inheritdoc IERC6372
    function CLOCK_MODE() external pure returns (string memory) {
        return "mode=epoch";
    }

    /// @inheritdoc IDistributionVault
    function getClaimDigest(
        address token_,
        uint256 startEpoch_,
        uint256 endEpoch_,
        address destination_,
        uint256 nonce_,
        uint256 deadline_
    ) public view returns (bytes32) {
        return
            _getDigest(
                keccak256(abi.encode(CLAIM_TYPEHASH, token_, startEpoch_, endEpoch_, destination_, nonce_, deadline_))
            );
    }

    /// @inheritdoc IERC6372
    function clock() public view returns (uint48) {
        return uint48(PureEpochs.currentEpoch());
    }

    /// @inheritdoc IDistributionVault
    function getClaimable(
        address token_,
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) public view returns (uint256 claimable_) {
        uint256 currentEpoch_ = clock();

        if (endEpoch_ >= currentEpoch_) revert NotPastTimepoint(endEpoch_, currentEpoch_); // Range must be past epochs.

        // Starting must be before or same as end epoch.
        if (startEpoch_ > endEpoch_) revert StartEpochAfterEndEpoch(startEpoch_, endEpoch_);

        uint256[] memory balances_ = IZeroToken(zeroToken).pastBalancesOf(account_, startEpoch_, endEpoch_);
        uint256[] memory totalSupplies_ = IZeroToken(zeroToken).pastTotalSupplies(startEpoch_, endEpoch_);
        uint256 epochCount_ = endEpoch_ - startEpoch_ + 1;

        for (uint256 index_; index_ < epochCount_; ++index_) {
            uint256 balance_ = balances_[index_];

            // Skip epochs with no Zero token balance (i.e. no distribution).
            if (balance_ == 0) continue;

            if (hasClaimed[token_][startEpoch_ + index_][account_]) continue;

            // Scale the amount by `_GRANULARITY` to avoid some amount of truncation while accumulating.
            claimable_ +=
                (distributionOfAt[token_][startEpoch_ + index_] * balance_ * _GRANULARITY) /
                totalSupplies_[index_];
        }

        unchecked {
            // Divide the accumulated amount by `_GRANULARITY` to get the actual claimable amount.
            return claimable_ / _GRANULARITY;
        }
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    /**
     * @notice Allows a caller to claim `token_` distribution between inclusive epochs `startEpoch` and `endEpoch`.
     * @param  account_    The address of the account claiming the token.
     * @param  token_       The address of the token being claimed.
     * @param  startEpoch_  The starting epoch number as a clock value.
     * @param  endEpoch_    The ending epoch number as a clock value.
     * @param  destination_ The address the account where the claimed token will be sent.
     * @return claimed_     The total amount of token claimed by `account_`.
     */
    function _claim(
        address account_,
        address token_,
        uint256 startEpoch_,
        uint256 endEpoch_,
        address destination_
    ) internal returns (uint256 claimed_) {
        if (destination_ == address(0)) revert InvalidDestinationAddress();

        claimed_ = getClaimable(token_, account_, startEpoch_, endEpoch_);

        // NOTE: `getClaimable` skips epochs the account already claimed, so we can safely mark all epochs as claimed.
        // NOTE: This effectively iterates over the range again (is done in `getClaimable`), but the alternative is
        //       a lot of code duplication.
        for (uint256 epoch_ = startEpoch_; epoch_ < endEpoch_ + 1; ++epoch_) {
            hasClaimed[token_][epoch_][account_] = true;
        }

        _lastTokenBalances[token_] -= claimed_; // Track this contract's latest balance of `token_`.

        emit Claim(token_, account_, startEpoch_, endEpoch_, claimed_);

        if (!ERC20Helper.transfer(token_, destination_, claimed_)) revert TransferFailed();
    }
}
