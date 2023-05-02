// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "test/shared/SPOG_Base.t.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "forge-std/console.sol";

interface IMockConfig {
    function someValue() external view returns (uint256);
}

interface IMockConfigV2 {
    function someValue() external view returns (uint256);
    function someNewAddress() external view returns (address);
}

contract MockConfigNoERC165 is IMockConfig {
    uint256 public immutable someValue = 1;
}

contract MockConfigWithERC165 is IMockConfig, ERC165 {
    uint256 public immutable someValue = 1;

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IMockConfig).interfaceId || super.supportsInterface(interfaceId);
    }
}

contract MockConfigWithERC165v2 is IMockConfigV2, ERC165 {
    uint256 public immutable someValue = 1;
    address public immutable someNewAddress = address(0x123);

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IMockConfigV2).interfaceId || interfaceId == type(IMockConfig).interfaceId
            || super.supportsInterface(interfaceId);
    }
}

contract SPOG_ChangeConfig is SPOG_Base {
    function test_Revert_WhenContractDoesNotSupportERC165() public {
        MockConfigNoERC165 badConfig = new MockConfigNoERC165();

        vm.expectRevert();
        vm.prank(address(voteGovernor));
        spog.changeConfig(keccak256("MockConfigNoERC165"), address(badConfig), type(IMockConfig).interfaceId);
    }

    function test_Revert_WhenContractDoesSupportERC165_ButInterfaceDoesntMatch() public {
        MockConfigWithERC165 badConfig = new MockConfigWithERC165();

        bytes memory expectedError = abi.encodeWithSignature("ConfigERC165Unsupported()");

        vm.expectRevert(expectedError);
        vm.prank(address(voteGovernor));
        spog.changeConfig(keccak256("MockConfigWithERC165"), address(badConfig), type(IMockConfigV2).interfaceId);
    }

    function test_Revert_WhenNewContractDoesNotMatchExistingContract() public {
        MockConfigWithERC165v2 configV2 = new MockConfigWithERC165v2();

        vm.prank(address(voteGovernor));
        spog.changeConfig(keccak256("MockConfigWithERC165"), address(configV2), type(IMockConfigV2).interfaceId);

        MockConfigWithERC165 config = new MockConfigWithERC165();

        vm.expectRevert();
        vm.prank(address(voteGovernor));
        spog.changeConfig(keccak256("MockConfigWithERC165"), address(config), type(IMockConfig).interfaceId);
    }

    function test_NamedConfigCanBeSet() public {
        MockConfigWithERC165 config = new MockConfigWithERC165();

        vm.prank(address(voteGovernor));
        spog.changeConfig(keccak256("MockConfigWithERC165"), address(config), type(IMockConfig).interfaceId);

        (address configAddress,) = spog.getConfig(keccak256("MockConfigWithERC165"));
        assertTrue(configAddress == address(config), "Config not set");
    }
}
