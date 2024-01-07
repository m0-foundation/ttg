// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { StatefulERC712 } from "../lib/common/src/StatefulERC712.sol";

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { PureEpochs } from "./libs/PureEpochs.sol";

import { IZeroToken } from "./interfaces/IZeroToken.sol";

import { IDistributionVault } from "./interfaces/IDistributionVault.sol";

/// @title A contract enabling pro rate distribution of arbitrary tokens to holders of the Zero Token.
contract DistributionVault is IDistributionVault, StatefulERC712 {
    // keccak256("Claim(address token,uint256 startEpoch,uint256 endEpoch,address destination,uint256 nonce,uint256 deadline)")
    bytes32 public constant CLAIM_TYPEHASH = 0x8ef9cf97bc3ef1919633bb182b1a99bc91c2fa874c3ae8681d86bbffd5539a84;

    address public immutable zeroToken;

    mapping(address token => uint256 balance) internal _lastTokenBalances;

    mapping(address token => mapping(uint256 epoch => uint256 amount)) public distributionOfAt;

    mapping(address token => mapping(uint256 epoch => mapping(address account => bool claimed))) public hasClaimed;

    constructor(address zeroToken_) StatefulERC712("DistributionVault") {
        if ((zeroToken = zeroToken_) == address(0)) revert InvalidZeroTokenAddress();
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function claim(
        address token_,
        uint256 startEpoch_,
        uint256 endEpoch_,
        address destination_
    ) external returns (uint256 claimed_) {
        return _claim(msg.sender, token_, startEpoch_, endEpoch_, destination_);
    }

    function claimBySig(
        address account_,
        address token_,
        uint256 startEpoch_,
        uint256 endEpoch_,
        address destination_,
        uint256 deadline_,
        bytes memory signature_
    ) external returns (uint256 claimed) {
        uint256 currentNonce_ = nonces[account_];
        bytes32 digest_ = getClaimDigest(token_, startEpoch_, endEpoch_, destination_, currentNonce_, deadline_);

        _revertIfInvalidSignature(account_, digest_, signature_);
        _revertIfExpired(deadline_);

        unchecked {
            nonces[account_] = currentNonce_ + 1; // Nonce realistically cannot overflow.
        }

        return _claim(account_, token_, startEpoch_, endEpoch_, destination_);
    }

    function distribute(address token_) external returns (uint256 amount_) {
        uint256 currentEpoch_ = clock();
        uint256 lastTokenBalance_ = _lastTokenBalances[token_];

        // Determine the additional balance of `token_` tha is not accounted for in `lastTokenBalance_`.
        amount_ = IERC20(token_).balanceOf(address(this)) - lastTokenBalance_;

        emit Distribution(token_, currentEpoch_, amount_);

        distributionOfAt[token_][currentEpoch_] += amount_; // Add the amount to the distribution for the current epoch.
        _lastTokenBalances[token_] = lastTokenBalance_ + amount_; // Track this contract's latest balance of `token_`.
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function name() external view returns (string memory name_) {
        return _name;
    }

    function getClaimDigest(
        address token_,
        uint256 startEpoch_,
        uint256 endEpoch_,
        address destination_,
        uint256 nonce_,
        uint256 deadline_
    ) public view returns (bytes32 digest_) {
        return
            _getDigest(
                keccak256(abi.encode(CLAIM_TYPEHASH, token_, startEpoch_, endEpoch_, destination_, nonce_, deadline_))
            );
    }

    function CLOCK_MODE() external pure returns (string memory clockMode_) {
        return "mode=epoch";
    }

    function clock() public view returns (uint48 clock_) {
        return uint48(PureEpochs.currentEpoch());
    }

    function getClaimable(
        address token_,
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) public view returns (uint256 claimable_) {
        uint256 currentEpoch_ = clock();

        if (endEpoch_ >= currentEpoch_) revert NotPastTimepoint(endEpoch_, currentEpoch_); // Range must be past epochs.

        uint256[] memory balances_ = IZeroToken(zeroToken).pastBalancesOf(account_, startEpoch_, endEpoch_);
        uint256[] memory totalSupplies_ = IZeroToken(zeroToken).pastTotalSupplies(startEpoch_, endEpoch_);
        uint256 epochCount_ = endEpoch_ - startEpoch_ + 1;

        for (uint256 index_; index_ < epochCount_; ++index_) {
            uint256 balance_ = balances_[index_];
            uint256 totalSupply_ = totalSupplies_[index_];

            claimable_ += hasClaimed[token_][startEpoch_ + index_][account_]
                ? 0
                : (distributionOfAt[token_][startEpoch_ + index_] * balance_) / totalSupply_;
        }
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _claim(
        address account_,
        address token_,
        uint256 startEpoch_,
        uint256 endEpoch_,
        address destination_
    ) internal returns (uint256 claimed_) {
        claimed_ = getClaimable(token_, account_, startEpoch_, endEpoch_);

        // NOTE: `getClaimable` skips epochs the account already claimed, so we can safely mark all epochs as claimed.
        for (uint256 epoch_ = startEpoch_; epoch_ < endEpoch_ + 1; ++epoch_) {
            hasClaimed[token_][epoch_][account_] = true;
        }

        _lastTokenBalances[token_] -= claimed_; // Track this contract's latest balance of `token_`.

        emit Claim(token_, account_, startEpoch_, endEpoch_, claimed_);

        if (!ERC20Helper.transfer(token_, destination_, claimed_)) revert TransferFailed();
    }
}
