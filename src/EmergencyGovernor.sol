// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ThresholdGovernor } from "./abstract/ThresholdGovernor.sol";

import { IEmergencyGovernor } from "./interfaces/IEmergencyGovernor.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IStandardGovernor } from "./interfaces/IStandardGovernor.sol";

/**
 * @title  An instance of a ThresholdGovernor with a unique and limited set of possible proposals.
 * @author M^0 Labs
 */
contract EmergencyGovernor is IEmergencyGovernor, ThresholdGovernor {
    /* ============ Variables ============ */

    /// @inheritdoc IEmergencyGovernor
    address public immutable registrar;

    /// @inheritdoc IEmergencyGovernor
    address public immutable standardGovernor;

    /// @inheritdoc IEmergencyGovernor
    address public immutable zeroGovernor;

    /* ============ Modifiers ============ */

    /// @dev Throws if called by any account other than the Zero Governor.
    modifier onlyZeroGovernor() {
        if (msg.sender != zeroGovernor) revert NotZeroGovernor();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructs a new Emergency Governor contract.
     * @param  voteToken_        The address of the Vote Token contract.
     * @param  zeroGovernor_     The address of the Zero Governor contract.
     * @param  registrar_        The address of the Registrar contract.
     * @param  standardGovernor_ The address of the StandardGovernor contract.
     * @param  thresholdRatio_   The initial threshold ratio.
     */
    constructor(
        address voteToken_,
        address zeroGovernor_,
        address registrar_,
        address standardGovernor_,
        uint16 thresholdRatio_
    ) ThresholdGovernor("EmergencyGovernor", voteToken_, thresholdRatio_) {
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((registrar = registrar_) == address(0)) revert InvalidRegistrarAddress();
        if ((standardGovernor = standardGovernor_) == address(0)) revert InvalidStandardGovernorAddress();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IEmergencyGovernor
    function setThresholdRatio(uint16 newThresholdRatio_) external onlyZeroGovernor {
        _setThresholdRatio(newThresholdRatio_);
    }

    /* ============ Proposal Functions ============ */

    /// @inheritdoc IEmergencyGovernor
    function addToList(bytes32 list_, address account_) external onlySelf {
        _addToList(list_, account_);
    }

    /// @inheritdoc IEmergencyGovernor
    function removeFromList(bytes32 list_, address account_) external onlySelf {
        _removeFromList(list_, account_);
    }

    /// @inheritdoc IEmergencyGovernor
    function removeFromAndAddToList(bytes32 list_, address accountToRemove_, address accountToAdd_) external onlySelf {
        _removeFromList(list_, accountToRemove_);
        _addToList(list_, accountToAdd_);
    }

    /// @inheritdoc IEmergencyGovernor
    function setKey(bytes32 key_, bytes32 value_) external onlySelf {
        IRegistrar(registrar).setKey(key_, value_);
    }

    /// @inheritdoc IEmergencyGovernor
    function setStandardProposalFee(uint256 newProposalFee_) external onlySelf {
        IStandardGovernor(standardGovernor).setProposalFee(newProposalFee_);
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev   Adds `account_` to `list_` at the Registrar.
     * @param list_    The key for some list.
     * @param account_ The address of some account to be added.
     */
    function _addToList(bytes32 list_, address account_) internal {
        IRegistrar(registrar).addToList(list_, account_);
    }

    /**
     * @dev   Removes `account_` from `list_` at the Registrar.
     * @param list_    The key for some list.
     * @param account_ The address of some account to be removed.
     */
    function _removeFromList(bytes32 list_, address account_) internal {
        IRegistrar(registrar).removeFromList(list_, account_);
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
            !(func_ == this.addToList.selector && length == _SELECTOR_PLUS_2_ARGS) &&
            !(func_ == this.removeFromList.selector && length == _SELECTOR_PLUS_2_ARGS) &&
            !(func_ == this.removeFromAndAddToList.selector && length == _SELECTOR_PLUS_3_ARGS) &&
            !(func_ == this.setKey.selector && length == _SELECTOR_PLUS_2_ARGS) &&
            !(func_ == this.setStandardProposalFee.selector && length == _SELECTOR_PLUS_1_ARGS)
        ) revert InvalidCallData();
    }
}
