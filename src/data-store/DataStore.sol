// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Type, TypeLib} from "src/data-store/Type.sol";
import {TypedValue, TypedValueLib} from "src/data-store/TypedValue.sol";

contract DataStore is Ownable {
    using TypedValueLib for *;
    using TypeLib for Type;

    /// Errors ///
    error KeyIsNil();
    error ValueIsNil();
    error MapAlreadyExists();
    error MapDoesNotExist();
    error UnexpectedType(uint256 got, uint256 expected);

    /// Permissioning ///
    mapping(address => bool) public writers;

    /// Variables ///

    // variable name => variable value
    mapping(string => TypedValue) public variables;

    /// Depth 1 Maps ///

    struct TypedKVPair {
        Type key;
        Type value;
    }

    // map name => (key => value)
    mapping(string => TypedKVPair) public depth1MapsTypes;
    mapping(string => mapping(bytes => bytes)) public depth1MapsValues;

    /// Depth 2 Maps ///

    struct TypedKKVTuple {
        Type key1;
        Type key2;
        Type value;
    }

    // map name => (key => (key => value))
    mapping(string => TypedKKVTuple) public depth2MapsTypes;
    mapping(string => mapping(bytes => mapping(bytes => bytes))) public depth2MapsValues;

    constructor() Ownable() {}

    /// permissioning
    function setWriter(address _writer, bool isWriter) external onlyOwner {
        writers[_writer] = isWriter;
    }

    modifier onlyOwnerOrWriter() {
        require(owner() == msg.sender || writers[msg.sender], "DataStore: only owner or writer");
        _;
    }

    /// individual variables

    function setAddressVariable(string memory _name, address _address) public onlyOwnerOrWriter {
        variables[_name] = _address.toTypedValue();
    }

    function getAddressVariable(string memory _name) public view returns (address) {
        if (variables[_name].valueType == Type.NIL) {
            return address(0);
        }
        return variables[_name].unwrapAsAddress();
    }

    function setBoolVariable(string calldata _name, bool _bool) public onlyOwnerOrWriter {
        variables[_name] = _bool.toTypedValue();
    }

    function getBoolVariable(string calldata _name) public view returns (bool) {
        if (variables[_name].valueType == Type.NIL) {
            return false;
        }
        return variables[_name].unwrapAsBool();
    }

    function setBytesVariable(string memory _name, bytes memory _bytes) public onlyOwnerOrWriter {
        variables[_name] = _bytes.toTypedValue();
    }

    function getBytesVariable(string memory _name) public view returns (bytes memory) {
        if (variables[_name].valueType == Type.NIL) {
            return bytes("");
        }
        return variables[_name].unwrapAsBytes();
    }

    function setStringVariable(string calldata _name, string calldata _string) public onlyOwnerOrWriter {
        variables[_name] = _string.toTypedValue();
    }

    function getStringVariable(string calldata _name) public view returns (string memory) {
        if (variables[_name].valueType == Type.NIL) {
            return "";
        }
        return variables[_name].unwrapAsString();
    }

    function setUint256Variable(string calldata _name, uint256 _uint256) public onlyOwnerOrWriter {
        variables[_name] = _uint256.toTypedValue();
    }

    function getUint256Variable(string calldata _name) public view returns (uint256) {
        if (variables[_name].valueType == Type.NIL) {
            return 0;
        }
        return variables[_name].unwrapAsUint256();
    }

    /// depth 1 maps

    function createMap(string calldata _mapName, Type _key, Type _value) public onlyOwnerOrWriter {
        if (_key == Type.NIL) {
            revert KeyIsNil();
        }
        if (_value == Type.NIL) {
            revert ValueIsNil();
        }
        if (mapExists(_mapName)) {
            revert MapAlreadyExists();
        }
        depth1MapsTypes[_mapName] = TypedKVPair({key: _key, value: _value});
    }

    function mapExists(string calldata _mapName) public view returns (bool) {
        return depth1MapsTypes[_mapName].key != Type.NIL;
    }

    function setKeyValuePair(string calldata _mapName, TypedValue calldata _key, TypedValue calldata _value)
        public
        onlyOwnerOrWriter
    {
        if (depth1MapsTypes[_mapName].key == Type.NIL) {
            revert MapDoesNotExist();
        }
        if (_key.valueType != depth1MapsTypes[_mapName].key) {
            revert UnexpectedType(_key.valueType.toInt(), depth1MapsTypes[_mapName].key.toInt());
        }
        if (_value.valueType != depth1MapsTypes[_mapName].value) {
            revert UnexpectedType(_value.valueType.toInt(), depth1MapsTypes[_mapName].value.toInt());
        }
        depth1MapsValues[_mapName][_key.value] = _value.value;
    }

    function getKeyValuePair(string calldata _mapName, TypedValue calldata _key)
        public
        view
        returns (TypedValue memory)
    {
        if (_key.valueType != depth1MapsTypes[_mapName].key) {
            revert UnexpectedType(_key.valueType.toInt(), depth1MapsTypes[_mapName].key.toInt());
        }
        bytes memory _value = depth1MapsValues[_mapName][_key.value];
        return TypedValue({valueType: depth1MapsTypes[_mapName].value, value: _value});
    }

    /// depth 2 maps

    function createDepth2Map(string calldata _mapName, Type _key1, Type _key2, Type _value) public onlyOwnerOrWriter {
        if (_key1 == Type.NIL || _key2 == Type.NIL) {
            revert KeyIsNil();
        }
        if (_value == Type.NIL) {
            revert ValueIsNil();
        }
        if (depth2MapExists(_mapName)) {
            revert MapAlreadyExists();
        }
        depth2MapsTypes[_mapName] = TypedKKVTuple({key1: _key1, key2: _key2, value: _value});
    }

    function depth2MapExists(string calldata _mapName) public view returns (bool) {
        return depth2MapsTypes[_mapName].key1 != Type.NIL;
    }

    function setKeyKeyValueTuple(
        string calldata _mapName,
        TypedValue calldata _key1,
        TypedValue calldata _key2,
        TypedValue calldata _value
    ) public onlyOwnerOrWriter {
        if (depth2MapsTypes[_mapName].key1 == Type.NIL) {
            revert MapDoesNotExist();
        }
        if (_key1.valueType != depth2MapsTypes[_mapName].key1 || _key2.valueType != depth2MapsTypes[_mapName].key2) {
            revert KeyIsNil();
        }
        if (_value.valueType != depth2MapsTypes[_mapName].value) {
            revert ValueIsNil();
        }
        depth2MapsValues[_mapName][_key1.value][_key2.value] = _value.value;
    }

    function getKeyKeyValueTuple(string calldata _mapName, TypedValue calldata _key1, TypedValue calldata _key2)
        public
        view
        returns (TypedValue memory)
    {
        if (_key1.valueType != depth2MapsTypes[_mapName].key1) {
            revert KeyIsNil();
        }
        if (_key2.valueType != depth2MapsTypes[_mapName].key2) {
            revert KeyIsNil();
        }
        bytes memory _value = depth2MapsValues[_mapName][_key1.value][_key2.value];
        return TypedValue({valueType: depth2MapsTypes[_mapName].value, value: _value});
    }
}
