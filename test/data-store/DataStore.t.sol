// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {DataStore} from "src/data-store/DataStore.sol";
import {TypedValue, TypedValueLib} from "src/data-store/TypedValue.sol";
import {Type, TypeLib} from "src/data-store/Type.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ContractWithDataStore is DataStore {
    constructor() DataStore() {}
}

contract DataStoreTest is Test {
    using TypedValueLib for *;
    using TypeLib for Type;

    DataStore public contractWithDataStore;
    address public nonOwner = address(0x1);
    address public writer = address(0x22);

    function setUp() public {
        // deploy contract which inherits from DataStore
        contractWithDataStore = new ContractWithDataStore();
        contractWithDataStore.setWriter(writer, true);
    }

    /// Permissioning
    function test_OnlyOwnerCanSetWriter() public {
        vm.startPrank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        contractWithDataStore.setWriter(nonOwner, true);
        vm.stopPrank();
    }

    /// Variable tests

    function test_GetAndSetAddress() public {
        string memory _name = "myAddress";
        address _address = address(0x123);
        contractWithDataStore.setAddressVariable(_name, _address);
        address _retreivedAddress = contractWithDataStore.getAddressVariable(_name);
        assert(_retreivedAddress == _address);

        // only owner can set addresses
        vm.startPrank(nonOwner);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.setAddressVariable(_name, _address);
        vm.stopPrank();

        // writer can write address
        vm.startPrank(writer);
        _address = address(0x456);
        contractWithDataStore.setAddressVariable(_name, _address);
        _retreivedAddress = contractWithDataStore.getAddressVariable(_name);
        assert(_retreivedAddress == _address);
        vm.stopPrank();

        // writer cannot write after being removed
        contractWithDataStore.setWriter(writer, false);
        vm.startPrank(writer);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.setAddressVariable(_name, address(0x789));
        vm.stopPrank();

        // get unset address
        string memory _unsetAddrName = "unset address";
        address _unsetAddress = contractWithDataStore.getAddressVariable(_unsetAddrName);
        assert(_unsetAddress == address(0));
    }

    function test_GetAndSetBoolAttribute() public {
        string memory _name = "myBool";
        bool _bool = true;
        contractWithDataStore.setBoolVariable(_name, _bool);
        bool _retreivedBool = contractWithDataStore.getBoolVariable(_name);
        assert(_retreivedBool == _bool);

        // only owner can set bools
        vm.startPrank(nonOwner);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.setBoolVariable(_name, _bool);
        vm.stopPrank();

        // writer can write bool
        vm.startPrank(writer);
        _bool = true;
        contractWithDataStore.setBoolVariable(_name, _bool);
        _retreivedBool = contractWithDataStore.getBoolVariable(_name);
        assert(_retreivedBool == _bool);
        vm.stopPrank();

        // writer cannot write after being removed
        contractWithDataStore.setWriter(writer, false);
        vm.startPrank(writer);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.setBoolVariable(_name, _bool);
        vm.stopPrank();

        // get unset bool
        string memory _unsetName = "unset bool";
        bool _unsetBool = contractWithDataStore.getBoolVariable(_unsetName);
        assert(_unsetBool == false);
    }

    function test_GetAndSetBytesAttribute() public {
        string memory _name = "myBytes";
        bytes memory _bytes = bytes("bytes");
        contractWithDataStore.setBytesVariable(_name, _bytes);
        bytes memory _retreivedBytes = contractWithDataStore.getBytesVariable(_name);
        assert(keccak256(_retreivedBytes) == keccak256(_bytes));

        // only owner can set bytes
        vm.startPrank(nonOwner);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.setBytesVariable(_name, _bytes);
        vm.stopPrank();

        // writer can write bytes
        vm.startPrank(writer);
        _bytes = bytes("bytes2");
        contractWithDataStore.setBytesVariable(_name, _bytes);
        _retreivedBytes = contractWithDataStore.getBytesVariable(_name);
        assert(keccak256(_retreivedBytes) == keccak256(_bytes));
        vm.stopPrank();

        // writer cannot write after being removed
        contractWithDataStore.setWriter(writer, false);
        vm.startPrank(writer);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.setBytesVariable(_name, _bytes);
        vm.stopPrank();

        // get unset bytes
        string memory _unsetName = "unset bytes";
        bytes memory _unsetBytes = contractWithDataStore.getBytesVariable(_unsetName);
        assert(keccak256(_unsetBytes) == keccak256(bytes("")));
    }

    function test_GetAndSetStringAttribute() public {
        string memory _name = "myString";
        string memory _string = "string";
        contractWithDataStore.setStringVariable(_name, _string);
        string memory _retreivedString = contractWithDataStore.getStringVariable(_name);
        assert(keccak256(bytes(_retreivedString)) == keccak256(bytes(_string)));

        // only owner can set strings
        vm.startPrank(nonOwner);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.setStringVariable(_name, _string);
        vm.stopPrank();

        // writer can write strings
        vm.startPrank(writer);
        _string = "string2";
        contractWithDataStore.setStringVariable(_name, _string);
        _retreivedString = contractWithDataStore.getStringVariable(_name);
        assert(keccak256(bytes(_retreivedString)) == keccak256(bytes(_string)));
        vm.stopPrank();

        // writer cannot write after being removed
        contractWithDataStore.setWriter(writer, false);
        vm.startPrank(writer);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.setStringVariable(_name, _string);
        vm.stopPrank();

        // get unset string
        string memory _unsetName = "unset string";
        string memory _unsetString = contractWithDataStore.getStringVariable(_unsetName);
        assert(keccak256(abi.encode(_unsetString)) == keccak256(abi.encode("")));
    }

    function test_GetAndSetUint256Attribute() public {
        string memory _name = "myUint256";
        uint256 _uint256 = 123;
        contractWithDataStore.setUint256Variable(_name, _uint256);
        uint256 _retreivedUint256 = contractWithDataStore.getUint256Variable(_name);
        assert(_retreivedUint256 == _uint256);

        // only owner can set uint256s
        vm.startPrank(nonOwner);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.setUint256Variable(_name, _uint256);
        vm.stopPrank();

        // writer can write uints
        vm.startPrank(writer);
        _uint256 = 456;
        contractWithDataStore.setUint256Variable(_name, _uint256);
        _retreivedUint256 = contractWithDataStore.getUint256Variable(_name);
        assert(_retreivedUint256 == _uint256);
        vm.stopPrank();

        // writer cannot write after being removed
        contractWithDataStore.setWriter(writer, false);
        vm.startPrank(writer);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.setUint256Variable(_name, _uint256);
        vm.stopPrank();

        // get unset uint256
        string memory _unsetName = "unset uint256";
        uint256 _unsetUint256 = contractWithDataStore.getUint256Variable(_unsetName);
        assert(_unsetUint256 == 0);
    }

    /// Map (key-value pair) tests
    function test_NonWritersCannotCreateMap() public {
        string memory _name = "myMap";
        string memory _name2 = "myMap2";

        // only owner can create map
        vm.startPrank(nonOwner);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.createMap(_name, Type.STRING, Type.STRING);
        vm.stopPrank();

        // writer can create map
        vm.startPrank(writer);
        contractWithDataStore.createMap(_name, Type.STRING, Type.STRING);
        vm.stopPrank();

        // writer cannot create map after being removed
        contractWithDataStore.setWriter(writer, false);
        vm.startPrank(writer);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.createMap(_name2, Type.STRING, Type.STRING);
        vm.stopPrank();
    }

    function test_RevertCreateMapWithNilKeyValue() public {
        string memory _name = "myMap";
        vm.expectRevert(abi.encodeWithSignature("KeyIsNil()"));
        contractWithDataStore.createMap(_name, Type.NIL, Type.STRING);
        vm.expectRevert(abi.encodeWithSignature("ValueIsNil()"));
        contractWithDataStore.createMap(_name, Type.STRING, Type.NIL);
    }

    function test_RevertCreateMapTwice() public {
        string memory _name = "myMap";
        contractWithDataStore.createMap(_name, Type.ADDRESS, Type.STRING);
        vm.expectRevert(abi.encodeWithSignature("MapAlreadyExists()"));
        // even if you try to create a map with the same name but diff types it should fail
        contractWithDataStore.createMap(_name, Type.ADDRESS, Type.UINT256);
    }

    function test_RevertTestSetKeyValuePairOnNonexistentMap() public {
        string memory _mapName = "myMap";
        TypedValue memory _key = string("myKey").toTypedValue();
        TypedValue memory _value = string("myValue").toTypedValue();

        // set key-value pair on nonexistent map
        vm.expectRevert(abi.encodeWithSignature("MapDoesNotExist()"));
        contractWithDataStore.setKeyValuePair(_mapName, _key, _value);
    }

    function test_SetAndGetKeyValuePair() public {
        string memory _mapName = "myMap";
        // create a mapping(string=>string)
        contractWithDataStore.createMap(_mapName, Type.STRING, Type.STRING);

        // set key-value pair
        TypedValue memory _key = string("myKey").toTypedValue();
        TypedValue memory _value = string("myValue").toTypedValue();
        contractWithDataStore.setKeyValuePair(_mapName, _key, _value);

        // get key-value pair
        TypedValue memory _typedValue = contractWithDataStore.getKeyValuePair(_mapName, _key);
        string memory _retrievedString = _typedValue.unwrapAsString();
        assert(_typedValue.valueType == Type.STRING);
        assert(keccak256(abi.encode(_retrievedString)) == keccak256(abi.encode("myValue")));
    }

    function test_RevertSetKeyValuePairWithIncorrectKeyType() public {
        // create a mapping(string=>string) but try to set with another key-value type pair
        string memory _mapName = "myMap";
        contractWithDataStore.createMap(_mapName, Type.STRING, Type.STRING);

        // set key-value pair with invalid key type
        TypedValue memory _key1 = address(0x234).toTypedValue();
        TypedValue memory _value1 = string("myValue").toTypedValue();
        vm.expectRevert(
            abi.encodeWithSignature("UnexpectedType(uint256,uint256)", Type.ADDRESS.toInt(), Type.STRING.toInt())
        );
        contractWithDataStore.setKeyValuePair(_mapName, _key1, _value1);

        // set key-value pair with invalid value type
        TypedValue memory _key2 = string("myKey").toTypedValue();
        TypedValue memory _value2 = uint256(1).toTypedValue();
        vm.expectRevert(
            abi.encodeWithSignature("UnexpectedType(uint256,uint256)", Type.UINT256.toInt(), Type.STRING.toInt())
        );
        contractWithDataStore.setKeyValuePair(_mapName, _key2, _value2);
    }

    /// Depth 2 Map tests

    function test_NonWritersCannotCreateDepth2Maps() public {
        string memory _name = "myMap";
        string memory _name2 = "myMap2";

        // only owner can create map
        vm.startPrank(nonOwner);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.createDepth2Map(_name, Type.STRING, Type.STRING, Type.STRING);
        vm.stopPrank();

        // writer can create map
        vm.startPrank(writer);
        contractWithDataStore.createDepth2Map(_name, Type.STRING, Type.STRING, Type.STRING);
        vm.stopPrank();

        // writer cannot create map after being removed
        contractWithDataStore.setWriter(writer, false);
        vm.startPrank(writer);
        vm.expectRevert("DataStore: only owner or writer");
        contractWithDataStore.createDepth2Map(_name2, Type.STRING, Type.STRING, Type.STRING);
        vm.stopPrank();
    }

    function test_CannotCreateDepth2MapsWithNilKKV() public {
        string memory _name = "myMap";
        vm.expectRevert(abi.encodeWithSignature("KeyIsNil()"));
        contractWithDataStore.createDepth2Map(_name, Type.NIL, Type.STRING, Type.STRING);
        vm.expectRevert(abi.encodeWithSignature("KeyIsNil()"));
        contractWithDataStore.createDepth2Map(_name, Type.STRING, Type.NIL, Type.STRING);
        vm.expectRevert(abi.encodeWithSignature("ValueIsNil()"));
        contractWithDataStore.createDepth2Map(_name, Type.STRING, Type.STRING, Type.NIL);
    }

    function test_RevertCreateDepth2MapTwice() public {
        string memory _name = "myDepth2Map";
        contractWithDataStore.createDepth2Map(_name, Type.ADDRESS, Type.STRING, Type.BOOL);
        vm.expectRevert(abi.encodeWithSignature("MapAlreadyExists()"));
        // even if you try to create a map with the same name but diff types it should fail
        contractWithDataStore.createDepth2Map(_name, Type.ADDRESS, Type.UINT256, Type.BYTES);
    }

    function test_RevertTestAndSetKeyKeyValueTupleNonexistentMap() public {
        string memory _mapName = "myMap";
        TypedValue memory _key = string("myKey").toTypedValue();
        TypedValue memory _key2 = string("myKey2").toTypedValue();
        TypedValue memory _value = string("myValue").toTypedValue();

        // set key-value pair on nonexistent map
        vm.expectRevert(abi.encodeWithSignature("MapDoesNotExist()"));
        contractWithDataStore.setKeyKeyValueTuple(_mapName, _key, _key2, _value);
    }

    function test_SetAndGetKeyValuePairOnDepth2Map() public {
        string memory _mapName = "myMap";
        // create a mapping(string=>mapping(string=>string))
        contractWithDataStore.createDepth2Map(_mapName, Type.STRING, Type.STRING, Type.STRING);

        // set key-value pair
        TypedValue memory _key1 = string("myKey1").toTypedValue();
        TypedValue memory _key2 = string("myKey2").toTypedValue();
        TypedValue memory _value = string("myValue").toTypedValue();
        contractWithDataStore.setKeyKeyValueTuple(_mapName, _key1, _key2, _value);

        // get key-value pair
        TypedValue memory _typedValue = contractWithDataStore.getKeyKeyValueTuple(_mapName, _key1, _key2);
        string memory _retrievedString = _typedValue.unwrapAsString();
        assert(_typedValue.valueType == Type.STRING);
        assert(keccak256(abi.encode(_retrievedString)) == keccak256(abi.encode("myValue")));
    }
}
