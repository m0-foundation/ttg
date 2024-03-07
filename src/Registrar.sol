// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IEmergencyGovernorDeployer } from "./interfaces/IEmergencyGovernorDeployer.sol";
import { IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";
import { IZeroGovernor } from "./interfaces/IZeroGovernor.sol";

/*

████████╗████████╗ ██████╗     ██████╗ ███████╗ ██████╗ ██╗███████╗████████╗██████╗  █████╗ ██████╗ 
╚══██╔══╝╚══██╔══╝██╔════╝     ██╔══██╗██╔════╝██╔════╝ ██║██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗
   ██║      ██║   ██║  ███╗    ██████╔╝█████╗  ██║  ███╗██║███████╗   ██║   ██████╔╝███████║██████╔╝
   ██║      ██║   ██║   ██║    ██╔══██╗██╔══╝  ██║   ██║██║╚════██║   ██║   ██╔══██╗██╔══██║██╔══██╗
   ██║      ██║   ╚██████╔╝    ██║  ██║███████╗╚██████╔╝██║███████║   ██║   ██║  ██║██║  ██║██║  ██║
   ╚═╝      ╚═╝    ╚═════╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝
                                                                                                    

*/

/**
 * @title  A book of record of TTG-specific contracts and arbitrary key-value pairs and lists.
 * @author M^0 Labs
 */
contract Registrar is IRegistrar {
    /* ============ Variables ============ */

    /// @inheritdoc IRegistrar
    address public immutable emergencyGovernorDeployer;

    /// @inheritdoc IRegistrar
    address public immutable powerTokenDeployer;

    /// @inheritdoc IRegistrar
    address public immutable standardGovernorDeployer;

    /// @inheritdoc IRegistrar
    address public immutable vault;

    /// @inheritdoc IRegistrar
    address public immutable zeroGovernor;

    /// @inheritdoc IRegistrar
    address public immutable zeroToken;

    /// @dev A mapping of keys to values.
    mapping(bytes32 key => bytes32 value) internal _valueAt;

    /* ============ Modifiers ============ */

    /// @dev Revert if the caller is not the Standard Governor nor the Emergency Governor.
    modifier onlyStandardOrEmergencyGovernor() {
        _revertIfNotStandardOrEmergencyGovernor();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructs a new Registrar contract.
     * @param  zeroGovernor_ The address of the ZeroGovernor contract.
     */
    constructor(address zeroGovernor_) {
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();

        IZeroGovernor zeroGovernorInstance_ = IZeroGovernor(zeroGovernor_);

        if ((emergencyGovernorDeployer = zeroGovernorInstance_.emergencyGovernorDeployer()) == address(0))
            revert InvalidEmergencyGovernorDeployerAddress();

        if ((powerTokenDeployer = zeroGovernorInstance_.powerTokenDeployer()) == address(0))
            revert InvalidPowerTokenDeployerAddress();

        address standardGovernorDeployer_ = standardGovernorDeployer = zeroGovernorInstance_.standardGovernorDeployer();

        if (standardGovernorDeployer_ == address(0)) revert InvalidStandardGovernorDeployerAddress();

        if ((zeroToken = zeroGovernorInstance_.voteToken()) == address(0)) revert InvalidVoteTokenAddress();

        if ((vault = IStandardGovernorDeployer(standardGovernorDeployer_).vault()) == address(0))
            revert InvalidVaultAddress();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IRegistrar
    function addToList(bytes32 list_, address account_) external onlyStandardOrEmergencyGovernor {
        _valueAt[_getIsInListKey(list_, account_)] = bytes32(uint256(1));

        emit AddressAddedToList(list_, account_);
    }

    /// @inheritdoc IRegistrar
    function removeFromList(bytes32 list_, address account_) external onlyStandardOrEmergencyGovernor {
        delete _valueAt[_getIsInListKey(list_, account_)];

        emit AddressRemovedFromList(list_, account_);
    }

    /// @inheritdoc IRegistrar
    function setKey(bytes32 key_, bytes32 value_) external onlyStandardOrEmergencyGovernor {
        emit KeySet(key_, _valueAt[_getValueKey(key_)] = value_);
    }

    /* ============ View/Pure Functions ============ */

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

    /// @inheritdoc IRegistrar
    function emergencyGovernor() public view returns (address) {
        return IEmergencyGovernorDeployer(emergencyGovernorDeployer).lastDeploy();
    }

    /// @inheritdoc IRegistrar
    function standardGovernor() public view returns (address) {
        return IStandardGovernorDeployer(standardGovernorDeployer).lastDeploy();
    }

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Reverts if the caller is not the Standard Governor nor the Emergency Governor.
    function _revertIfNotStandardOrEmergencyGovernor() internal view {
        if (msg.sender != standardGovernor() && msg.sender != emergencyGovernor()) {
            revert NotStandardOrEmergencyGovernor();
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
