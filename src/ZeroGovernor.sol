// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ThresholdGovernor } from "./abstract/ThresholdGovernor.sol";

import { IEmergencyGovernor } from "./interfaces/IEmergencyGovernor.sol";
import { IEmergencyGovernorDeployer } from "./interfaces/IEmergencyGovernorDeployer.sol";
import { IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";
import { IStandardGovernor } from "./interfaces/IStandardGovernor.sol";
import { IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";
import { IZeroGovernor } from "./interfaces/IZeroGovernor.sol";

/**
 * @title  An instance of a ThresholdGovernor with a unique and limited set of possible proposals.
 * @author M^0 Labs
 */
contract ZeroGovernor is IZeroGovernor, ThresholdGovernor {
    /* ============ Variables ============ */

    /// @dev The maximum number of Zero tokens that can be rewarded per active epoch.
    uint256 internal constant _MAX_TOTAL_ZERO_REWARD_PER_ACTIVE_EPOCH = 5_000_000e6;

    /// @inheritdoc IZeroGovernor
    address public immutable emergencyGovernorDeployer;

    /// @inheritdoc IZeroGovernor
    address public immutable powerTokenDeployer;

    /// @inheritdoc IZeroGovernor
    address public immutable standardGovernorDeployer;

    /// @dev The set of allowed cash tokens.
    mapping(address token => bool allowed) internal _allowedCashTokens;

    /* ============ Constructor ============ */

    /**
     * @notice Construct a new ZeroGovernor contract.
     * @param  voteToken_                       The address of the token used to vote.
     * @param  emergencyGovernorDeployer_       The address of the Emergency Governor Deployer contract.
     * @param  powerTokenDeployer_              The address of the Power Token Deployer contract.
     * @param  standardGovernorDeployer_        The address of the Standard Governor Deployer contract.
     * @param  bootstrapToken_                  The address of the token that bootstraps the reset.
     * @param  standardProposalFee_             The proposal fee for the Standard Governor.
     * @param  emergencyProposalThresholdRatio_ The threshold ratio for the Emergency Governor.
     * @param  zeroProposalThresholdRatio_      The threshold ratio for the Zero Governor.
     * @param  allowedCashTokens_               The set of allowed cash tokens.
     */
    constructor(
        address voteToken_,
        address emergencyGovernorDeployer_,
        address powerTokenDeployer_,
        address standardGovernorDeployer_,
        address bootstrapToken_,
        uint256 standardProposalFee_,
        uint16 emergencyProposalThresholdRatio_,
        uint16 zeroProposalThresholdRatio_,
        address[] memory allowedCashTokens_
    ) ThresholdGovernor("ZeroGovernor", voteToken_, zeroProposalThresholdRatio_) {
        if ((emergencyGovernorDeployer = emergencyGovernorDeployer_) == address(0)) {
            revert InvalidEmergencyGovernorDeployerAddress();
        }

        if ((powerTokenDeployer = powerTokenDeployer_) == address(0)) {
            revert InvalidPowerTokenDeployerAddress();
        }

        if ((standardGovernorDeployer = standardGovernorDeployer_) == address(0)) {
            revert InvalidStandardGovernorDeployerAddress();
        }

        if (allowedCashTokens_.length == 0) revert NoAllowedCashTokens();

        for (uint256 index_; index_ < allowedCashTokens_.length; ++index_) {
            address allowedCashToken_ = allowedCashTokens_[index_];

            if (allowedCashToken_ == address(0)) revert InvalidCashTokenAddress();

            _allowedCashTokens[allowedCashToken_] = true;
        }

        emit AllowedCashTokensSet(allowedCashTokens_);

        // Deploy the ephemeral `standardGovernor`, `emergencyGovernor`, and `powerToken` contracts, where:
        // - the token to bootstrap the `powerToken` balances and voting powers is defined in the constructor
        // - the starting cash token is the first token in the `_allowedCashTokens` array
        // - the starting `emergencyGovernor` threshold ratio is defined in the constructor
        // - the starting `standardGovernor` proposal fee is defined in the constructor
        _deployEphemeralContracts(
            emergencyGovernorDeployer_,
            powerTokenDeployer_,
            standardGovernorDeployer_,
            bootstrapToken_,
            allowedCashTokens_[0],
            emergencyProposalThresholdRatio_,
            standardProposalFee_
        );
    }

    /* ============ Proposal Functions ============ */

    /// @inheritdoc IZeroGovernor
    function resetToPowerHolders() external onlySelf {
        _resetContracts(IStandardGovernor(standardGovernor()).voteToken());
    }

    /// @inheritdoc IZeroGovernor
    function resetToZeroHolders() external onlySelf {
        _resetContracts(voteToken);
    }

    /// @inheritdoc IZeroGovernor
    function setCashToken(address newCashToken_, uint256 newProposalFee_) external onlySelf {
        if (!_allowedCashTokens[newCashToken_]) revert InvalidCashToken();

        IStandardGovernor(standardGovernor()).setCashToken(newCashToken_, newProposalFee_);
    }

    /// @inheritdoc IZeroGovernor
    function setEmergencyProposalThresholdRatio(uint16 newThresholdRatio_) external onlySelf {
        IEmergencyGovernor(emergencyGovernor()).setThresholdRatio(newThresholdRatio_);
    }

    /// @inheritdoc IZeroGovernor
    function setZeroProposalThresholdRatio(uint16 newThresholdRatio_) external onlySelf {
        _setThresholdRatio(newThresholdRatio_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IZeroGovernor
    function isAllowedCashToken(address token_) external view returns (bool) {
        return _allowedCashTokens[token_];
    }

    /// @inheritdoc IZeroGovernor
    function emergencyGovernor() public view returns (address) {
        return IEmergencyGovernorDeployer(emergencyGovernorDeployer).lastDeploy();
    }

    /// @inheritdoc IZeroGovernor
    function standardGovernor() public view returns (address) {
        return IStandardGovernorDeployer(standardGovernorDeployer).lastDeploy();
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev    Deploys the ephemeral `standardGovernor`, `emergencyGovernor`, and `powerToken` contracts.
     * @param  emergencyGovernorDeployer_       The address of the Emergency Governor Deployer contract.
     * @param  powerTokenDeployer_              The address of the Power Token Deployer contract.
     * @param  standardGovernorDeployer_        The address of the Standard Governor Deployer contract.
     * @param  bootstrapToken_                  The address of a token to bootstrap the new Power Token.
     * @param  cashToken_                       The address of the Cash Token contract.
     * @param  emergencyProposalThresholdRatio_ The threshold ratio for the Emergency Governor.
     * @param  proposalFee_                     The proposal fee for the Standard Governor.
     * @return standardGovernor_                The address of the deployed Standard Governor contract.
     * @return emergencyGovernor_               The address of the deployed Emergency Governor contract.
     * @return powerToken_                      The address of the deployed Power Token contract.
     */
    function _deployEphemeralContracts(
        address emergencyGovernorDeployer_,
        address powerTokenDeployer_,
        address standardGovernorDeployer_,
        address bootstrapToken_,
        address cashToken_,
        uint16 emergencyProposalThresholdRatio_,
        uint256 proposalFee_
    ) internal returns (address standardGovernor_, address emergencyGovernor_, address powerToken_) {
        address expectedPowerToken_ = IPowerTokenDeployer(powerTokenDeployer_).nextDeploy();
        address expectedStandardGovernor_ = IStandardGovernorDeployer(standardGovernorDeployer_).nextDeploy();

        emergencyGovernor_ = IEmergencyGovernorDeployer(emergencyGovernorDeployer_).deploy(
            expectedPowerToken_,
            expectedStandardGovernor_,
            emergencyProposalThresholdRatio_
        );

        standardGovernor_ = IStandardGovernorDeployer(standardGovernorDeployer_).deploy(
            expectedPowerToken_,
            emergencyGovernor_,
            cashToken_,
            proposalFee_,
            _MAX_TOTAL_ZERO_REWARD_PER_ACTIVE_EPOCH
        );

        if (expectedStandardGovernor_ != standardGovernor_) {
            revert UnexpectedStandardGovernorDeployed(expectedPowerToken_, powerToken_);
        }

        powerToken_ = IPowerTokenDeployer(powerTokenDeployer_).deploy(bootstrapToken_, standardGovernor_, cashToken_);

        if (expectedPowerToken_ != powerToken_) revert UnexpectedPowerTokenDeployed(expectedPowerToken_, powerToken_);
    }

    /**
     * @dev   Redeploy the ephemeral `standardGovernor`, `emergencyGovernor`, and `powerToken` contracts, where:
     *         - the cash token is the same cash token in the existing `standardGovernor`
     *         - the `emergencyGovernor` threshold ratio is the same threshold ratio in the existing `emergencyGovernor`
     *         - the `standardGovernor` proposal fee is the same proposal fee in the existing `standardGovernor`
     * @param bootstrapToken_ The token to bootstrap the `powerToken` balances and voting powers.
     */
    function _resetContracts(address bootstrapToken_) internal {
        IStandardGovernor standardGovernor_ = IStandardGovernor(standardGovernor());

        (
            address newStandardGovernor_,
            address newEmergencyGovernor_,
            address newPowerToken_
        ) = _deployEphemeralContracts(
                emergencyGovernorDeployer,
                powerTokenDeployer,
                standardGovernorDeployer,
                bootstrapToken_,
                standardGovernor_.cashToken(),
                IEmergencyGovernor(emergencyGovernor()).thresholdRatio(),
                standardGovernor_.proposalFee()
            );

        emit ResetExecuted(bootstrapToken_, newStandardGovernor_, newEmergencyGovernor_, newPowerToken_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev   All proposals target this contract itself, and must call one of the listed functions to be valid.
     * @param callData_ The call data to check.
     */
    function _revertIfInvalidCalldata(bytes memory callData_) internal pure override {
        bytes4 func_ = bytes4(callData_);
        uint256 length = callData_.length;

        if (
            !(func_ == this.resetToPowerHolders.selector && length == _SELECTOR_PLUS_0_ARGS) &&
            !(func_ == this.resetToZeroHolders.selector && length == _SELECTOR_PLUS_0_ARGS) &&
            !(func_ == this.setCashToken.selector && length == _SELECTOR_PLUS_2_ARGS) &&
            !(func_ == this.setEmergencyProposalThresholdRatio.selector && length == _SELECTOR_PLUS_1_ARGS) &&
            !(func_ == this.setZeroProposalThresholdRatio.selector && length == _SELECTOR_PLUS_1_ARGS)
        ) revert InvalidCallData();
    }
}
