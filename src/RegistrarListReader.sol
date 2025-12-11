// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IRegistrarListReader } from "./interfaces/IRegistrarListReader.sol";

/*
 * @title  A read-only helper contract for reading standard (address) and bytes32 lists from the Registrar.
 * @dev This contract fills a gap in the functionality of the base registrar contract by allowing users to
 *      treat key-value pairs on the registrar with a key format as lists.
 * @author M^0 Labs
 */
contract RegistrarListReader is IRegistrarListReader {
    /* ============ State ============ */

    bytes32 internal constant ZERO_WORD = bytes32(0);
    address public immutable registrar;

    /* ============ Constructor ============ */
    
    constructor(address registrar_) {
        if (registrar_ == address(0)) revert InvalidRegistrarAddress();
        registrar = registrar_;
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IRegistrarListReader
    function listContains(bytes32 list_, address account_) external view returns (bool) {
        return IRegistrar(registrar).listContains(list_, account_);
    }

    /// @inheritdoc IRegistrarListReader
    function listContains(bytes32 list_, address[] calldata accounts_) external view returns (bool) {
        return IRegistrar(registrar).listContains(list_, accounts_);
    }

    /// @inheritdoc IRegistrarListReader
    function listContains(bytes32 list_, bytes32 account_) external view returns (bool) {
        return _isSetOnRegistrar(list_, account_);
    }

    /// @inheritdoc IRegistrarListReader
    function listContains(bytes32 list_, bytes32[] calldata accounts_) external view returns (bool) {
        uint256 len = accounts_.length;

        for (uint256 index_; index_ < len; ++index_) {
            if (!_isSetOnRegistrar(list_, accounts_[index_])) {
                return false;
            }
        }

        return true;
    }

    /* ========== HELPERS ========== */

    /*
     * @notice Returns whether the key formed by `keccak256(abi.encodePacked(list, value))` is set on the Registrar.
     * @param list  The key for some list.
     * @param value The bytes32 value to check for membership in `list`.
     */
    function _isSetOnRegistrar(bytes32 list, bytes32 value) internal view returns (bool) {
        bytes32 key = keccak256(abi.encodePacked(list, value));

        bytes32 isSet = IRegistrar(registrar).get(key);

        // Note: the idea is that these values would be set to 0 or 1,
        // but they don't necessarily have to be, so we check if not 0
        return isSet != ZERO_WORD;
    }
}
