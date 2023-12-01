// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { ERC712 } from "../lib/common/src/ERC712.sol";

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { PureEpochs } from "./libs/PureEpochs.sol";

import { IEpochBasedVoteToken } from "./abstract/interfaces/IEpochBasedVoteToken.sol";

import { IDistributionVault } from "./interfaces/IDistributionVault.sol";

contract DistributionVault is IDistributionVault, ERC712 {
    // keccak256("Claim(address token,uint256 startEpoch,uint256 endEpoch,address destination,uint256 nonce,uint256 deadline)")
    bytes32 public constant CLAIM_TYPEHASH = 0x8ef9cf97bc3ef1919633bb182b1a99bc91c2fa874c3ae8681d86bbffd5539a84;

    address public immutable baseToken;

    mapping(address token => uint256 balance) internal _lastTokenBalances;

    mapping(address token => mapping(uint256 epoch => uint256 amount)) internal _distributions;

    mapping(address token => mapping(uint256 epoch => mapping(address account => bool claimed))) internal _claims;

    constructor(address baseToken_) ERC712("DistributionVault") {
        baseToken = baseToken_;
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
        _revertIfExpired(deadline_);

        uint256 currentNonce_ = _nonces[account_];
        bytes32 digest_ = _getClaimDigest(token_, startEpoch_, endEpoch_, destination_, currentNonce_, deadline_);

        _revertIfInvalidSignature(account_, digest_, signature_);

        unchecked {
            _nonces[account_] = currentNonce_ + 1; // Nonce realistically cannot overflow.
        }

        return _claim(account_, token_, startEpoch_, endEpoch_, destination_);
    }

    function distribute(address token_) external {
        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        uint256 lastTokenBalances_ = _lastTokenBalances[token_];

        uint256 amount_ = IERC20(token_).balanceOf(address(this)) - lastTokenBalances_;

        emit Distribution(token_, currentEpoch_, amount_);

        _distributions[token_][currentEpoch_] += amount_;

        _lastTokenBalances[token_] = lastTokenBalances_ + amount_;
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function getClaimable(
        address token_,
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) public view returns (uint256 claimable_) {
        uint256[] memory balances_ = IEpochBasedVoteToken(baseToken).balancesOfBetween(
            account_,
            startEpoch_,
            endEpoch_
        );

        uint256[] memory totalSupplies_ = IEpochBasedVoteToken(baseToken).totalSuppliesBetween(startEpoch_, endEpoch_);

        uint256 epochCount_ = endEpoch_ - startEpoch_ + 1;

        for (uint256 index_; index_ < epochCount_; ++index_) {
            claimable_ += _getClaimable(
                token_,
                account_,
                startEpoch_ + index_,
                balances_[index_],
                totalSupplies_[index_]
            );
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

        for (uint256 epoch_ = startEpoch_; epoch_ <= endEpoch_; ++epoch_) {
            _claims[token_][epoch_][account_] = true;
        }

        // TODO: Consider replacing with a balance check and optional `distribute`.
        _lastTokenBalances[token_] -= claimed_;

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
        if (epoch_ >= PureEpochs.currentEpoch()) revert EpochTooHigh();

        if (_claims[token_][epoch_][account_]) return 0;

        return (_distributions[token_][epoch_] * balance_) / totalSupply_;
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
            _getDigest(
                keccak256(abi.encode(CLAIM_TYPEHASH, token_, startEpoch_, endEpoch_, destination_, nonce_, deadline_))
            );
    }
}
