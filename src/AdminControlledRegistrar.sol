// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IEmergencyGovernorDeployer } from "./interfaces/IEmergencyGovernorDeployer.sol";
import { IERC6372 } from "./abstract/interfaces/IERC6372.sol";
import { IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";
import { IZeroGovernor } from "./interfaces/IZeroGovernor.sol";

import { PureEpochs } from "./libs/PureEpochs.sol";

/**
 * @title  A book of record of TTG-specific contracts and arbitrary key-value pairs and lists.
 * @dev    A simplified version of Registrar for testnet
 * @author M^0 Labs
 */
contract AdminControlledRegistrar is IRegistrar {
    /* ============ Variables ============ */

    /// @inheritdoc IRegistrar
    address public immutable emergencyGovernorDeployer;

    /// @inheritdoc IRegistrar
    address public immutable powerTokenDeployer;

    /// @inheritdoc IRegistrar
    address public immutable standardGovernorDeployer;

    /// @inheritdoc IRegistrar
    address public vault;

    /// @inheritdoc IRegistrar
    address public immutable zeroGovernor;

    /// @inheritdoc IRegistrar
    address public immutable zeroToken;

    /// @inheritdoc IRegistrar
    address public emergencyGovernor;

    /// @inheritdoc IRegistrar
    address public standardGovernor;

    /// @dev A mapping of keys to values.
    mapping(bytes32 key => bytes32 value) internal _valueAt;

    address public admin;

    event AdminSet(address admin_);
    event VaultSet(address vault_);
    event EmergencyGovernorSet(address governor_);
    event StandardGovernorSet(address governor_);

    error NotAdmin();

    /* ============ Modifiers ============ */

    /// @dev Revert if the caller is not the admin.
    modifier onlyAdmin() {
        _revertIfNotAdmin();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructs a new Admin Controlled Registrar contract.
     */
    constructor(address admin_, address vault_) {
        admin = admin_;
        vault = vault_;
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IRegistrar
    function addToList(bytes32 list_, address account_) external onlyAdmin {
        _valueAt[_getIsInListKey(list_, account_)] = bytes32(uint256(1));

        emit AddressAddedToList(list_, account_);
    }

    /// @inheritdoc IRegistrar
    function removeFromList(bytes32 list_, address account_) external onlyAdmin {
        delete _valueAt[_getIsInListKey(list_, account_)];

        emit AddressRemovedFromList(list_, account_);
    }

    /// @inheritdoc IRegistrar
    function setKey(bytes32 key_, bytes32 value_) external onlyAdmin {
        emit KeySet(key_, _valueAt[_getValueKey(key_)] = value_);
    }

    function changeAdmin(address admin_) external onlyAdmin {
        admin = admin_;
        emit AdminSet(admin_);
    }

    function setVault(address vault_) external onlyAdmin {
        vault = vault_;
        emit VaultSet(vault_);
    }

    function setEmergencyGovernor(address emergencyGovernor_) external onlyAdmin {
        emergencyGovernor = emergencyGovernor_;
        emit EmergencyGovernorSet(emergencyGovernor_);
    }

    function setStandardGovernor(address standardGovernor_) external onlyAdmin {
        standardGovernor = standardGovernor_;
        emit StandardGovernorSet(standardGovernor_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IERC6372
    function clock() external view returns (uint48) {
        return PureEpochs.currentEpoch();
    }

    /// @inheritdoc IRegistrar
    function get(bytes32 key_) external view returns (bytes32) {
        return _valueAt[_getValueKey(key_)];
    }

    /// @inheritdoc IRegistrar
    function get(bytes32[] calldata keys_) external view returns (bytes32[] memory values_) {
        values_ = new bytes32[](keys_.length);

        for (uint256 index_; index_ < keys_.length; ++index_) {
            values_[index_] = _valueAt[_getValueKey(keys_[index_])];
        }
    }

    /// @inheritdoc IRegistrar
    function listContains(bytes32 list_, address account_) external view returns (bool) {
        return _valueAt[_getIsInListKey(list_, account_)] == bytes32(uint256(1));
    }

    /// @inheritdoc IRegistrar
    function listContains(bytes32 list_, address[] calldata accounts_) external view returns (bool) {
        for (uint256 index_; index_ < accounts_.length; ++index_) {
            if (_valueAt[_getIsInListKey(list_, accounts_[index_])] != bytes32(uint256(1))) return false;
        }

        return true;
    }

    /// @inheritdoc IRegistrar
    function powerToken() external view returns (address) {
        return IPowerTokenDeployer(powerTokenDeployer).lastDeploy();
    }

    /// @inheritdoc IERC6372
    function CLOCK_MODE() external pure returns (string memory) {
        return PureEpochs.clockMode();
    }

    /// @inheritdoc IRegistrar
    function clockStartingTimestamp() external pure returns (uint256) {
        return PureEpochs.STARTING_TIMESTAMP;
    }

    /// @inheritdoc IRegistrar
    function clockPeriod() external pure returns (uint256) {
        return PureEpochs.EPOCH_PERIOD;
    }

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Reverts if the caller is not the admin.
    function _revertIfNotAdmin() internal view {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
    }

    /**
     * @dev    Returns the key used to store the value of `key_`.
     * @param  key_ The key of the value.
     * @return The key used to store the value of `key_`.
     */
    function _getValueKey(bytes32 key_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("VALUE", key_));
    }

    /**
     * @dev    Returns the key used to store whether `account_` is in `list_`.
     * @param  list_    The list of addresses.
     * @param  account_ The address of the account.
     * @return The key used to store whether `account_` is in `list_`.
     */
    function _getIsInListKey(bytes32 list_, address account_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("IN_LIST", list_, account_));
    }
}
