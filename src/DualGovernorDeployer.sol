// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IDualGovernorDeployer } from "./interfaces/IDualGovernorDeployer.sol";

import { DualGovernor } from "./DualGovernor.sol";
import { ContractHelper } from "./ContractHelper.sol";

// TODO: `cashToken` can be a public immutable if it will never change.

contract DualGovernorDeployer is IDualGovernorDeployer {
    address public immutable registrar;
    address public immutable vault;
    address public immutable zeroToken;

    address[] internal _allowedCashTokens;

    uint256 public nonce;

    modifier onlyRegistrar() {
        if (msg.sender != registrar) revert CallerIsNotRegistrar();

        _;
    }

    constructor(address registrar_, address vault_, address zeroToken_, address[] memory allowedCashTokens_) {
        if ((registrar = registrar_) == address(0)) revert ZeroRegistrarAddress();
        if ((vault = vault_) == address(0)) revert ZeroVaultAddress();
        if ((zeroToken = zeroToken_) == address(0)) revert ZeroZeroTokenAddress();

        for (uint256 index_; index_ < allowedCashTokens_.length; ++index_) {
            address allowedCashToken_ = allowedCashTokens_[index_];

            if (allowedCashToken_ == address(0)) revert ZeroCashTokenAddress();

            _allowedCashTokens.push(allowedCashToken_);
        }
    }

    function deploy(
        address powerToken_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_,
        uint16 powerTokenThresholdRatio_,
        uint16 zeroTokenThresholdRatio_
    ) external onlyRegistrar returns (address deployed_) {
        ++nonce;

        return
            address(
                new DualGovernor(
                    registrar,
                    powerToken_,
                    zeroToken,
                    vault,
                    _allowedCashTokens,
                    proposalFee_,
                    maxTotalZeroRewardPerActiveEpoch_,
                    powerTokenThresholdRatio_,
                    zeroTokenThresholdRatio_
                )
            );
    }

    function allowedCashTokens() external view returns (address[] memory tokens_) {
        return _allowedCashTokens;
    }

    function allowedCashTokensAt(uint256 index_) external view returns (address token_) {
        return _allowedCashTokens[index_];
    }

    function getNextDeploy() external view returns (address nextDeploy_) {
        return ContractHelper.getContractFrom(address(this), nonce + 1);
    }
}
