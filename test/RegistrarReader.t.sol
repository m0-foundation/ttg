// SPDX-License-Identifier: UNLICENCED

pragma solidity 0.8.23;

import { Test } from "lib/forge-std/src/Test.sol";
import { IRegistrar } from "src/interfaces/IRegistrar.sol";
import { Registrar } from "src/Registrar.sol";
import { RegistrarReader } from "src/RegistrarReader.sol";
import { IRegistrarReader } from "src/interfaces/IRegistrarReader.sol";

import { console2 } from "lib/forge-std/src/console2.sol";
// import { console } from "lib/forge-std/src/console.sol";

import {
    MockEmergencyGovernorDeployer,
    MockPowerTokenDeployer,
    MockStandardGovernorDeployer,
    MockZeroGovernor
} from "./utils/Mocks.sol";

contract RegistrarReaderTests is Test {

    address internal _account1 = makeAddr("account1");
    address internal _account2 = makeAddr("account2");
    address internal _account3 = makeAddr("account3");
    address internal _emergencyGovernor = makeAddr("emergencyGovernor");
    address internal _powerToken = makeAddr("powerToken");
    address internal _standardGovernor = makeAddr("standardGovernor");
    address internal _vault = makeAddr("vault");
    address internal _zeroToken = makeAddr("zeroToken");

    Registrar internal _registrar;
    RegistrarReader internal _reader;

    MockEmergencyGovernorDeployer internal _emergencyGovernorDeployer;
    MockPowerTokenDeployer internal _powerTokenDeployer;
    MockStandardGovernorDeployer internal _standardGovernorDeployer;
    MockZeroGovernor internal _zeroGovernor;

    function setUp() public {

        _emergencyGovernorDeployer = new MockEmergencyGovernorDeployer();
        _powerTokenDeployer = new MockPowerTokenDeployer();
        _standardGovernorDeployer = new MockStandardGovernorDeployer();
        _zeroGovernor = new MockZeroGovernor();

        _emergencyGovernorDeployer.setLastDeploy(_emergencyGovernor);

        _powerTokenDeployer.setLastDeploy(_powerToken);

        _standardGovernorDeployer.setLastDeploy(_standardGovernor);
        _standardGovernorDeployer.setVault(_vault);

        _zeroGovernor.setEmergencyGovernorDeployer(address(_emergencyGovernorDeployer));
        _zeroGovernor.setPowerTokenDeployer(address(_powerTokenDeployer));
        _zeroGovernor.setStandardGovernorDeployer(address(_standardGovernorDeployer));
        _zeroGovernor.setVoteToken(_zeroToken);

        _registrar = new Registrar(address(_zeroGovernor));
        _reader = new RegistrarReader(address(_registrar));
    }

    /* ============ constructor ============ */
    function test_constructor_revertsOnZeroAddress() public {
        vm.expectRevert(IRegistrarReader.InvalidRegistrarAddress.selector);
        new RegistrarReader(address(0));
    }

    /* ============ get ============ */
    function test_get_singleKey() public {
        bytes32 key = bytes32("key1");
        bytes32 val = bytes32("val1");
        vm.prank(_standardGovernor);
        _registrar.setKey(key, val);

        bytes32 readVal = _reader.get(key);
        assertEq(readVal, val, "Reader.get should return stored value");
    }

    function test_get_multipleKeys() public {
        bytes32 key1 = bytes32("key1");
        bytes32 key2 = bytes32("key2");
        bytes32 val1 = bytes32("val1");
        bytes32 val2 = bytes32("val2");
        vm.prank(_standardGovernor);
        _registrar.setKey(key1, val1);
        vm.prank(_standardGovernor);
        _registrar.setKey(key2, val2);

        bytes32[] memory keys = new bytes32[](2);
        keys[0] = key1;
        keys[1] = key2;

        bytes32[] memory values = _reader.get(keys);
        assertEq(values.length, 2, "values length");
        assertEq(values[0], val1, "value[0]");
        assertEq(values[1], val2, "value[1]");
    }

    /* ============ listContains(address) ============ */
    function test_listContains_address_single() public {
        // Initially false
        assertFalse(_reader.listContains("someList", _account1));

        // Add and check true
        vm.prank(_standardGovernor);
        _registrar.addToList("someList", _account1);
        assertTrue(_reader.listContains("someList", _account1));

        // Other address still false
        assertFalse(_reader.listContains("someList", _account2));
    }

    function test_listContains_address_array() public {
        address[] memory group1 = new address[](2);
        group1[0] = _account1;
        group1[1] = _account2;

        address[] memory group2 = new address[](3);
        group2[0] = _account1;
        group2[1] = _account2;
        group2[2] = _account3;

        // Empty array should be true (loop passes)
        address[] memory empty = new address[](0);
        assertTrue(_reader.listContains("someList", empty));

        // Add _account1,_account2; group1 -> true
        vm.prank(_standardGovernor);
        _registrar.addToList("someList", _account1);
        vm.prank(_standardGovernor);
        _registrar.addToList("someList", _account2);
        assertTrue(_reader.listContains("someList", group1));

        // group2 includes _account3 (not added) -> false
        assertFalse(_reader.listContains("someList", group2));

        // Add _account3; now group2 -> true
        vm.prank(_standardGovernor);
        _registrar.addToList("someList", _account3);
        assertTrue(_reader.listContains("someList", group2));
    }

    /* ============ listContains(bytes32) ============ */
    function test_listContains_bytes32_single_trueWhenNonZero() public {
        // Reader computes key = keccak256(list, value) and checks get(key) != 0
        bytes32 member = bytes32("m1");
        bytes32 key = keccak256(abi.encodePacked(bytes32("someList"), member));

        // Non-zero value (1) -> true
        vm.prank(_standardGovernor);
        _registrar.setKey(key, bytes32(uint256(1)));
        assertTrue(_reader.listContains("someList", member));

        // Different non-zero value (7) -> still true per reader's logic
        vm.prank(_standardGovernor);
        _registrar.setKey(key, bytes32(uint256(7)));
        assertTrue(_reader.listContains("someList", member));

        // Zero -> false
        vm.prank(_standardGovernor);
        _registrar.setKey(key, bytes32(0));
        assertFalse(_reader.listContains("someList", member));
    }

    function test_listContains_bytes32_array() public {
        bytes32 m1 = bytes32("m1");
        bytes32 m2 = bytes32("m2");
        bytes32 m3 = bytes32("m3");

        bytes32 key1 = keccak256(abi.encodePacked(bytes32("someList"), m1));
        bytes32 key2 = keccak256(abi.encodePacked(bytes32("someList"), m2));
        bytes32 key3 = keccak256(abi.encodePacked(bytes32("someList"), m3));

        // Set membership for m1, m2
        vm.prank(_standardGovernor);
        _registrar.setKey(key1, bytes32(uint256(1)));
        vm.prank(_standardGovernor);
        _registrar.setKey(key2, bytes32(uint256(1)));

        bytes32[] memory group1 = new bytes32[](2);
        group1[0] = m1;
        group1[1] = m2;
        assertTrue(_reader.listContains("someList", group1));

        bytes32[] memory group2 = new bytes32[](3);
        group2[0] = m1;
        group2[1] = m2;
        group2[2] = m3; // not set yet -> should be false
        assertFalse(_reader.listContains("someList", group2));

        // Set m3; now group2 -> true
        vm.prank(_standardGovernor);
        _registrar.setKey(key3, bytes32(uint256(1)));
        assertTrue(_reader.listContains("someList", group2));
    }

    /* ============ removeFromList ============ */

    function test_removeFromList_address() external {
        vm.prank(_standardGovernor);
        _registrar.addToList("someList", _account1);
        assertTrue(_reader.listContains("someList", _account1));

        vm.prank(_standardGovernor);
        _registrar.removeFromList("someList", _account1);
        assertFalse(_reader.listContains("someList", _account1));
    }

    function test_removeFromList_bytes32() external {
        bytes32 member = bytes32("m1");
        bytes32 list = bytes32("someList");
        bytes32 key = keccak256(abi.encodePacked(list, member));

        vm.prank(_standardGovernor);
        _registrar.setKey(key, bytes32(uint256(1)));
        assertTrue(_reader.listContains(list, member));

        vm.prank(_standardGovernor);
        _registrar.setKey(key, bytes32(0));
        assertFalse(_reader.listContains(list, member));
    }


    function test_removeFromList_multiple_address() external {
        vm.prank(_standardGovernor);
        _registrar.addToList("someList", _account1);
        vm.prank(_standardGovernor);
        _registrar.addToList("someList", _account2);
        vm.prank(_standardGovernor);
        _registrar.addToList("someList", _account3);

        address[] memory groupAll = new address[](3);
        groupAll[0] = _account1; groupAll[1] = _account2; groupAll[2] = _account3;
        assertTrue(_reader.listContains("someList", groupAll));

        // Remove _account2; groupAll should now be false
        vm.prank(_standardGovernor);
        _registrar.removeFromList("someList", _account2);
        assertFalse(_reader.listContains("someList", groupAll));

        // Remaining group without _account2 should be true
        address[] memory groupRemaining = new address[](2);
        groupRemaining[0] = _account1; groupRemaining[1] = _account3;
        assertTrue(_reader.listContains("someList", groupRemaining));
    }

    function test_removeFromList_multiple_bytes32() external {
        // Add multiple bytes32 members, remove one by zeroing value
        bytes32 list = bytes32("someList");
        bytes32 m1 = bytes32("m1");
        bytes32 m2 = bytes32("m2");
        bytes32 m3 = bytes32("m3");

        bytes32 k1 = keccak256(abi.encodePacked(list, m1));
        bytes32 k2 = keccak256(abi.encodePacked(list, m2));
        bytes32 k3 = keccak256(abi.encodePacked(list, m3));

        vm.prank(_standardGovernor);
        _registrar.setKey(k1, bytes32(uint256(1)));
        vm.prank(_standardGovernor);
        _registrar.setKey(k2, bytes32(uint256(1)));
        vm.prank(_standardGovernor);
        _registrar.setKey(k3, bytes32(uint256(1)));

        bytes32[] memory groupAll = new bytes32[](3);
        groupAll[0] = m1; groupAll[1] = m2; groupAll[2] = m3;
        assertTrue(_reader.listContains(list, groupAll));

        // Remove m2 via zeroing
        vm.prank(_standardGovernor);
        _registrar.setKey(k2, bytes32(0));
        assertFalse(_reader.listContains(list, groupAll));

        // Remaining group without m2 should be true
        bytes32[] memory groupRemaining = new bytes32[](2);
        groupRemaining[0] = m1; groupRemaining[1] = m3;
        assertTrue(_reader.listContains(list, groupRemaining));
    }
}
