// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {Type} from "src/data-store/Type.sol";

struct TypedValue {
    Type valueType;
    bytes value;
}

library TypedValueLib {
    function toTypedValue(address _address) internal pure returns (TypedValue memory) {
        return TypedValue(Type.ADDRESS, abi.encode(_address));
    }

    function toTypedValue(bool _bool) internal pure returns (TypedValue memory) {
        return TypedValue(Type.BOOL, abi.encode(_bool));
    }

    function toTypedValue(bytes memory _bytes) internal pure returns (TypedValue memory) {
        return TypedValue(Type.BYTES, _bytes);
    }

    function toTypedValue(string memory _string) internal pure returns (TypedValue memory) {
        return TypedValue(Type.STRING, abi.encode(_string));
    }

    function toTypedValue(uint256 _uint256) internal pure returns (TypedValue memory) {
        return TypedValue(Type.UINT256, abi.encode(_uint256));
    }

    function unwrapAsAddress(TypedValue memory _typedValue) internal pure returns (address) {
        require(_typedValue.valueType == Type.ADDRESS, "DataStore: invalid type");
        return abi.decode(_typedValue.value, (address));
    }

    function unwrapAsBool(TypedValue memory _typedValue) internal pure returns (bool) {
        require(_typedValue.valueType == Type.BOOL, "DataStore: invalid type");
        if (_typedValue.value.length == 0) {
            return false;
        }
        return abi.decode(_typedValue.value, (bool));
    }

    function unwrapAsBytes(TypedValue memory _typedValue) internal pure returns (bytes memory) {
        require(_typedValue.valueType == Type.BYTES, "DataStore: invalid type");
        if (_typedValue.value.length == 0) {
            return bytes("");
        }
        return _typedValue.value;
    }

    function unwrapAsString(TypedValue memory _typedValue) internal pure returns (string memory) {
        require(_typedValue.valueType == Type.STRING, "DataStore: invalid type");
        if (_typedValue.value.length == 0) {
            return "";
        }
        return abi.decode(_typedValue.value, (string));
    }

    function unwrapAsUint256(TypedValue memory _typedValue) internal pure returns (uint256) {
        require(_typedValue.valueType == Type.UINT256, "DataStore: invalid type");
        if (_typedValue.value.length == 0) {
            return 0;
        }
        return abi.decode(_typedValue.value, (uint256));
    }
}
