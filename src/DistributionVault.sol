// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { ERC712 } from "../lib/common/src/libs/ERC712.sol";

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
        uint256 currentNonce_ = _nonces[account_];
        bytes32 digest_ = _getClaimDigest(token_, startEpoch_, endEpoch_, destination_, currentNonce_, deadline_);

        ERC712.revertIfInvalidSignature(account_, digest_, signature_);
        ERC712.revertIfExpired(deadline_);

        unchecked {
            _nonces[account_] = currentNonce_ + 1; // Nonce realistically cannot overflow.
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
        uint256[] memory balances_ = IZeroToken(zeroToken).pastBalancesOf(account_, startEpoch_, endEpoch_);
        uint256[] memory totalSupplies_ = IZeroToken(zeroToken).pastTotalSupplies(startEpoch_, endEpoch_);
        uint256 epochCount_ = endEpoch_ - startEpoch_ + 1;

        for (uint256 index_; index_ < epochCount_; ++index_) {
            uint256 balance_ = balances_[index_];
            uint256 totalSupply_ = totalSupplies_[index_];

            claimable_ += _getClaimable(token_, account_, startEpoch_ + index_, balance_, totalSupply_);
        }
    }

    function name() external view returns (string memory name_) {
        return _name;
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

        // TODO: Consider replacing with a balance check and optional `distribute`.
        _lastTokenBalances[token_] -= claimed_; // Track this contract's latest balance of `token_`.

        emit Claim(token_, account_, startEpoch_, endEpoch_, claimed_);

        if (!ERC20Helper.transfer(token_, destination_, claimed_)) revert TransferFailed();
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _getClaimable(
        address token_,
        address account_,
        uint256 epoch_,
        uint256 balance_,
        uint256 totalSupply_
    ) internal view returns (uint256 claimable_) {
        uint256 currentEpoch_ = clock();

        if (epoch_ >= currentEpoch_) revert NotPastTimepoint(epoch_, currentEpoch_); // Must be a past epoch.

        return hasClaimed[token_][epoch_][account_] ? 0 : (distributionOfAt[token_][epoch_] * balance_) / totalSupply_;
    }

    function _getClaimDigest(
        address token_,
        uint256 startEpoch_,
        uint256 endEpoch_,
        address destination_,
        uint256 nonce_,
        uint256 deadline_
    ) internal view returns (bytes32 digest_) {
        return
            ERC712.getDigest(
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(CLAIM_TYPEHASH, token_, startEpoch_, endEpoch_, destination_, nonce_, deadline_))
            );
    }
}
